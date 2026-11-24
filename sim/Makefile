# Run from sim/
#   make uvm TEST=axi_rand_test SEED=1      -> one UVM test
#   make uvm TEST=axi_rand_test BUG=BUG_B3  -> same, with a planted bug (BUG_B1..BUG_B5)
#   make cov TEST=axi_pipe_test             -> functional + code + assertion coverage (urg_report/)
#   python3 regress.py                      -> full regression (6 configs x 3 tests)
TEST ?= axi_rand_test
SEED ?= 1
DEF   = $(if $(BUG),+define+$(BUG),)
VCS   = vcs -sverilog -full64 -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ps $(DEF)
CM    = line+cond+fsm+tgl+assert

uvm:
	$(VCS) -f filelist_uvm.f -l comp_uvm.log
	./simv +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) -l sim_uvm.log

cov:
	$(VCS) -cm $(CM) -cm_hier cm_hier.cfg -f filelist_uvm.f -l comp_cov.log
	./simv +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) -cm $(CM) -cm_name seed$(SEED) -l sim_cov.log
	urg -dir simv.vdb -format text -report urg_report

clean:
	rm -rf simv simv.daidir simv.vdb csrc urg_report logs *.log *.fsdb ucli.key vc_hdrs.h verdi* novas*

.PHONY: uvm cov clean
