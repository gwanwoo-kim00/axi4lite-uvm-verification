# AXI4-Lite peripheral regression report

total time: 41s

## Runs

| config | test | seed | result | writes | reads | mismatches | UVM_ERROR | UVM_FATAL | SVA | timer fails | func cov % | found by |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clean | axi_rand_test | 1 | PASS | 124 | 108 | 0 | 0 | 0 | 0 | 0 | 100.0 | - |
| clean | axi_rand_test | 2 | PASS | 111 | 121 | 0 | 0 | 0 | 0 | 0 | 100.0 | - |
| clean | axi_rand_test | 3 | PASS | 125 | 107 | 0 | 0 | 0 | 0 | 0 | 100.0 | - |
| clean | axi_rand_test | 4 | PASS | 108 | 124 | 0 | 0 | 0 | 0 | 0 | 100.0 | - |
| clean | axi_rand_test | 5 | PASS | 128 | 104 | 0 | 0 | 0 | 0 | 0 | 100.0 | - |
| clean | axi_timer_test | 1 | PASS | 12 | 8 | 0 | 0 | 0 | 0 | 0 | 45.5 | - |
| clean | axi_pipe_test | 1 | PASS | 124 | 108 | 0 | 0 | 0 | 0 | 0 | 100.0 | - |
| BUG_B1 | axi_rand_test | 1 | caught | 124 | 108 | 43 | 43 | 0 | 0 | 0 | 100.0 | Scoreboard(43) |
| BUG_B1 | axi_timer_test | 1 | missed | 12 | 8 | 0 | 0 | 0 | 0 | 0 | 45.5 | - |
| BUG_B1 | axi_pipe_test | 1 | caught | 124 | 108 | 43 | 43 | 0 | 0 | 0 | 100.0 | Scoreboard(43) |
| BUG_B2 | axi_rand_test | 1 | caught | 124 | 108 | 37 | 37 | 0 | 0 | 0 | 100.0 | Scoreboard(37) |
| BUG_B2 | axi_timer_test | 1 | missed | 12 | 8 | 0 | 0 | 0 | 0 | 0 | 45.5 | - |
| BUG_B2 | axi_pipe_test | 1 | caught | 124 | 108 | 35 | 35 | 0 | 0 | 0 | 100.0 | Scoreboard(35) |
| BUG_B3 | axi_rand_test | 1 | caught | 0 | 0 | -1 | 0 | 1 | 1 | 0 | - | SVA(1), Timeout/FATAL |
| BUG_B3 | axi_timer_test | 1 | missed | 12 | 8 | 0 | 0 | 0 | 0 | 0 | 45.5 | - |
| BUG_B3 | axi_pipe_test | 1 | caught | 0 | 0 | -1 | 0 | 1 | 1 | 0 | - | SVA(1), Timeout/FATAL |
| BUG_B4 | axi_rand_test | 1 | caught | 124 | 108 | 14 | 14 | 0 | 0 | 0 | 92.9 | Scoreboard(14) |
| BUG_B4 | axi_timer_test | 1 | missed | 12 | 8 | 0 | 0 | 0 | 0 | 0 | 45.5 | - |
| BUG_B4 | axi_pipe_test | 1 | caught | 124 | 108 | 14 | 14 | 0 | 0 | 0 | 92.9 | Scoreboard(14) |
| BUG_B5 | axi_rand_test | 1 | missed | 124 | 108 | 0 | 0 | 0 | 0 | 0 | 100.0 | - |
| BUG_B5 | axi_timer_test | 1 | caught | 12 | 8 | 0 | 1 | 0 | 0 | 1 | 45.5 | TimerTest(1) |
| BUG_B5 | axi_pipe_test | 1 | missed | 124 | 108 | 0 | 0 | 0 | 0 | 0 | 100.0 | - |

## Bugs

| bug | result | caught by test |
|---|---|---|
| BUG_B1 | DETECTED | axi_rand_test, axi_pipe_test |
| BUG_B2 | DETECTED | axi_rand_test, axi_pipe_test |
| BUG_B3 | DETECTED | axi_rand_test, axi_pipe_test |
| BUG_B4 | DETECTED | axi_rand_test, axi_pipe_test |
| BUG_B5 | DETECTED | axi_timer_test |

**overall: ALL GOOD**
