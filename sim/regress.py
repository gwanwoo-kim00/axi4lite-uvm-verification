#!/usr/bin/env python3
"""
AXI4-Lite UVM regression runner.

Usage (inside sim/):
    python3 regress.py              # clean: rand seeds 1-5 + timer + pipe; BUG_B1..B5: all 3 tests
    python3 regress.py --seeds 10   # clean rand_test with seeds 1-10

For each config (clean, BUG_B1..B5): compile once with VCS, run the tests (logs in logs/),
parse the logs and judge:
    clean run : PASS / FAIL
    bug run   : caught / missed by that test
    bug       : DETECTED if any test caught it, otherwise MISSED
Prints a table and writes regression_report.md.
"""
import argparse
import os
import re
import subprocess
import time

TESTS = ["axi_rand_test", "axi_timer_test", "axi_pipe_test"]
BUGS = ["BUG_B%d" % i for i in range(1, 6)]
VCS = ("vcs -sverilog -full64 -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ps "
       "{define} -f filelist_uvm.f -l logs/comp_{name}.log")
SIM = "./simv +UVM_TESTNAME={test} +ntb_random_seed={seed} -l logs/{name}_{test}_s{seed}.log"


def sh(cmd):
    """Run a shell command quietly. Returns the exit code (0 = OK)."""
    with open(os.devnull, "w") as null:
        return subprocess.call(cmd, shell=True, stdout=null, stderr=subprocess.STDOUT)


def parse_log(path):
    """Read one simulation log and pull out the numbers we care about."""
    r = {"writes": 0, "reads": 0, "mismatch": -1, "uvm_err": -1, "uvm_fatal": -1,
         "sva": 0, "cov": "-", "tmr_fail": 0}
    if not os.path.exists(path):
        return r
    text = open(path, errors="ignore").read()

    m = re.search(r"checked (\d+) writes, (\d+) reads, (\d+) mismatches", text)
    if m:
        r["writes"], r["reads"], r["mismatch"] = int(m.group(1)), int(m.group(2)), int(m.group(3))
    m = re.search(r"UVM_ERROR\s+:\s+(\d+)", text)
    if m:
        r["uvm_err"] = int(m.group(1))
    m = re.search(r"UVM_FATAL\s+:\s+(\d+)", text)
    if m:
        r["uvm_fatal"] = int(m.group(1))
    r["sva"] = text.count("[SVA]")
    m = re.search(r"functional coverage = ([\d.]+)%", text)
    if m:
        r["cov"] = m.group(1)
    # timer test summary:  timer test: 13 checks, 1 failed
    m = re.search(r"timer test: (\d+) checks, (\d+) failed", text)
    if m:
        r["tmr_fail"] = int(m.group(2))
    return r


def has_problem(r):
    return (r["mismatch"] != 0 or r["uvm_err"] != 0 or r["uvm_fatal"] != 0
            or r["sva"] > 0 or r["tmr_fail"] > 0)


def judge(bug, r):
    if bug is None:
        return "FAIL" if has_problem(r) else "PASS"
    return "caught" if has_problem(r) else "missed"


def how_found(r):
    """Which checker caught it (for the report)."""
    who = []
    if r["mismatch"] > 0:  who.append("Scoreboard({})".format(r["mismatch"]))
    if r["sva"] > 0:       who.append("SVA({})".format(r["sva"]))
    if r["tmr_fail"] > 0:  who.append("TimerTest({})".format(r["tmr_fail"]))
    if r["uvm_fatal"] > 0: who.append("Timeout/FATAL")
    return ", ".join(who) if who else "-"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, default=5, help="clean rand_test seeds 1..N")
    args = ap.parse_args()
    if not os.path.exists("filelist_uvm.f"):
        print("Run this script inside sim/"); return
    if not os.path.isdir("logs"):
        os.mkdir("logs")

    # (config, [(test, seed), ...])
    plan = [(None, [("axi_rand_test", s) for s in range(1, args.seeds + 1)] + [("axi_timer_test", 1), ("axi_pipe_test", 1)])]
    plan += [(b, [(t, 1) for t in TESTS]) for b in BUGS]

    rows, summary = [], []
    t0 = time.time()
    for bug, runs in plan:
        name = bug if bug else "clean"
        define = "+define+" + bug if bug else ""
        print("[COMPILE] {:8s} ...".format(name), end=" ", flush=True)
        if sh(VCS.format(define=define, name=name)) != 0:
            print("COMPILE ERROR (logs/comp_{}.log)".format(name))
            rows.append((name, "-", "-", "COMPILE_ERR", {}, "-"))
            summary.append((name, "COMPILE_ERR", "-"))
            continue
        print("ok")
        caught_by = []
        for test, s in runs:
            sh(SIM.format(test=test, seed=s, name=name))
            r = parse_log("logs/{}_{}_s{}.log".format(name, test, s))
            res = judge(bug, r)
            rows.append((name, test, s, res, r, how_found(r)))
            if res == "caught":
                caught_by.append(test)
            print("   {:15s} seed {:2d}: {:7s} wr={} rd={} mis={} err={} fatal={} sva={} tmr_fail={} cov={}".format(
                test, s, res, r["writes"], r["reads"], r["mismatch"], r["uvm_err"],
                r["uvm_fatal"], r["sva"], r["tmr_fail"], r["cov"]))
        if bug:
            summary.append((name, "DETECTED" if caught_by else "MISSED", ", ".join(caught_by) or "-"))

    # ---- report ----
    lines = ["# AXI4-Lite peripheral regression report", "",
             "total time: {:.0f}s".format(time.time() - t0), "",
             "## Runs", "",
             "| config | test | seed | result | writes | reads | mismatches | UVM_ERROR | UVM_FATAL | SVA | timer fails | func cov % | found by |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for name, test, s, res, r, who in rows:
        if not r:
            lines.append("| {} | - | - | {} | | | | | | | | | |".format(name, res)); continue
        lines.append("| {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} |".format(
            name, test, s, res, r["writes"], r["reads"], r["mismatch"], r["uvm_err"],
            r["uvm_fatal"], r["sva"], r["tmr_fail"], r["cov"], who))
    lines += ["", "## Bugs", "", "| bug | result | caught by test |", "|---|---|---|"]
    for name, res, by in summary:
        lines.append("| {} | {} | {} |".format(name, res, by))

    clean_ok = all(res == "PASS" for name, _, _, res, _, _ in rows if name == "clean")
    bugs_ok = all(res == "DETECTED" for _, res, _ in summary)
    lines += ["", "**overall: {}**".format("ALL GOOD" if (clean_ok and bugs_ok) else "CHECK FAILURES")]
    with open("regression_report.md", "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines[4:]))
    print("\n-> regression_report.md written")


if __name__ == "__main__":
    main()
