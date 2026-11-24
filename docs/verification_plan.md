# AXI4-Lite Peripheral 검증 계획서

## 1. 개요
- **DUT**: `rtl/axi4lite_slave.sv` (AXI4-Lite slave, 32-bit addr/data, 16 레지스터, LED · 스위치 · 타이머 · 인터럽트)
- **스펙**: `docs/peripheral_spec.md`
- **완료 기준**
  - clean RTL: 모든 테스트 PASS (UVM_ERROR 0, mismatch 0, SVA 위반 0)
  - 기능 커버리지 100%
  - 주입 버그 B1–B5 모두 하나 이상의 테스트에서 검출
  - SVA가 vacuous pass가 아닌 실제 검사로 동작 (URG Real Successes > 0)

## 2. 검증 항목
| ID | 항목 | 검사기 | 테스트 |
|---|---|---|---|
| F1 | 레지스터 write 후 read 값 일치 (RW) | RAL 스코어보드 | axi_rand_test |
| F2 | WSTRB 바이트 단위 쓰기 | RAL 스코어보드 + cp_strb | axi_rand_test |
| F3 | AW · W 순서 무관 (AW 먼저 / W 먼저 / 동시) | 랜덤 지연 + 스코어보드 | axi_rand_test |
| F4 | B · R back-pressure | 랜덤 BREADY/RREADY 지연 + SVA | axi_rand_test |
| F5 | 0x40 이상 주소 → SLVERR, read 0 | 스코어보드 응답 비교 | axi_rand_test |
| F6 | RO · RAZ/WI: 쓰기 무시 | RAL 접근 규칙 | axi_rand_test |
| F7 | SW_IN = 스위치 핀, LED 핀 = LED_OUT | directed check | axi_timer_test |
| F8 | 타이머 one-shot · auto-reload | directed check | axi_timer_test |
| F9 | W1C: 0 쓰기 유지, 1 쓰기 클리어 | directed check | axi_timer_test |
| F10 | irq = DONE & IRQ_EN | directed check | axi_timer_test |
| F11 | AW · W VALID/데이터 유지 (READY 대기 중) | SVA | axi_pipe_test |

## 3. 커버리지
- covergroup: 읽기/쓰기, 응답(OKAY/SLVERR), 잘못된 주소, 레지스터 16개, WSTRB 패턴, cross(rw×resp, rw×reg)
- URG: line · cond · fsm · toggle · assertion

## 4. 버그 주입
| 버그 | 내용 | 예상 검출 |
|---|---|---|
| B1 | WSTRB 무시 | 스코어보드 |
| B2 | W가 AW보다 먼저 오면 데이터 손실 | 스코어보드 |
| B3 | BREADY 없이 BVALID 하강 | SVA a_b_hold + timeout |
| B4 | 잘못된 주소에 OKAY | 스코어보드 |
| B5 | W1C가 데이터 비트 무시 | axi_timer_test |

## 5. 회귀
`sim/regress.py`: clean + BUG_B1–B5 × 3개 테스트 실행 → 로그 판정 → `regression_report.md`
