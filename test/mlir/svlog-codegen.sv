// RUN: moore -e Foo --format=mlir-native %s | FileCheck %s

// CHECK-LABEL: llhd.entity @Foo (
// CHECK-SAME:    [[ARG_X:%.+]] : !llhd.sig<i1>,
// CHECK-SAME:    [[ARG_Z:%.+]] : !llhd.sig<i3>
// CHECK-SAME:  ) -> (
// CHECK-SAME:    [[ARG_Y:%.+]] : !llhd.sig<i2>,
// CHECK-SAME:    [[ARG_UNDRIVEN_OUTPUT0:%.+]] : !llhd.sig<i4>
// CHECK-SAME:    [[ARG_UNDRIVEN_OUTPUT1:%.+]] : !llhd.sig<i5>
// CHECK-SAME:  ) {
module Foo (
  input bit x,
  output bit [1:0] y = 3,
  input bit [2:0] z,
  output bit [3:0] undriven_output0,
  output bit [4:0] undriven_output1 = 9
);

  //===--------------------------------------------------------------------===//
  // Declarations
  //===--------------------------------------------------------------------===//

  bit a = 0;
  wire bit b = a;
  // CHECK: [[DECL_A:%.+]] = llhd.sig "a" %false : i1
  // CHECK: [[DECL_B:%.+]] = llhd.sig "b" {{.+}} : i1
  // CHECK: llhd.con [[DECL_B]], [[DECL_A]] : !llhd.sig<i1>

  Bar bar();
  // CHECK: llhd.inst "bar" @Bar

  //===--------------------------------------------------------------------===//
  // Procedures
  //===--------------------------------------------------------------------===//

  initial;
  final;
  always;
  always_comb;
  always_latch;
  always_ff;
  // CHECK: llhd.inst "" @Foo.initial.
  // CHECK-NEXT: llhd.inst "" @Foo.final.
  // CHECK-NEXT: llhd.inst "" @Foo.always.
  // CHECK-NEXT: llhd.inst "" @Foo.always_comb.
  // CHECK-NEXT: llhd.inst "" @Foo.always_latch.
  // CHECK-NEXT: llhd.inst "" @Foo.always_ff.

  //===--------------------------------------------------------------------===//
  // Statements and Expressions
  //===--------------------------------------------------------------------===//

  initial begin
    -z;
    ~z;
  end

  initial if (x) begin end else begin end;

  initial repeat (10);
  initial while (x);
  initial do; while (x);
  initial for (; x; 42);
  initial forever 42;

  int c;
  initial begin c = 42; c; end
  initial begin c <= 42; c; end
  initial begin c <= #1ns 42; c; end

  // Undriven outputs are driven with a default value.
  // CHECK: [[TMP:%.+]] = hw.constant 0 : i4
  // CHECK-NEXT: [[TIME:%.+]] = llhd.constant_time
  // CHECK-NEXT: llhd.drv [[ARG_UNDRIVEN_OUTPUT0]], [[TMP]] after [[TIME]] : !llhd.sig<i4>
  // CHECK: [[TMP:%.+]] = hw.constant 9 : i5
  // CHECK-NEXT: [[TIME:%.+]] = llhd.constant_time
  // CHECK-NEXT: llhd.drv [[ARG_UNDRIVEN_OUTPUT1]], [[TMP]] after [[TIME]] : !llhd.sig<i5>

endmodule
// CHECK: }

// CHECK-LABEL: llhd.entity @Bar
module Bar;
endmodule
// CHECK: }

// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }

// CHECK-LABEL: llhd.proc @Foo.final.
// CHECK-NEXT:    [[TMP:%.+]] = llhd.constant_time
// CHECK-NEXT:    llhd.wait for [[TMP]], [[BB:\^.+]]
// CHECK-NEXT:  [[BB]]:
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }

// CHECK-LABEL: llhd.proc @Foo.always.
// CHECK-NEXT:    br [[BB:\^.+]]
// CHECK-NEXT:  [[BB]]:
// CHECK-NEXT:    br [[BB]]
// CHECK-NEXT:  }

// CHECK-LABEL: llhd.proc @Foo.always_comb.
// CHECK-NEXT:    br [[BB2:\^.+]]
// CHECK-NEXT:  [[BB2]]:
// CHECK-NEXT:    br [[BB1:\^.+]]
// CHECK-NEXT:  [[BB1]]:
// CHECK-NEXT:    llhd.wait [[BB2]]
// CHECK-NEXT:  }

// CHECK-LABEL: llhd.proc @Foo.always_latch.
// CHECK-NEXT:    br [[BB2:\^.+]]
// CHECK-NEXT:  [[BB2]]:
// CHECK-NEXT:    br [[BB1:\^.+]]
// CHECK-NEXT:  [[BB1]]:
// CHECK-NEXT:    llhd.wait [[BB2]]
// CHECK-NEXT:  }

// CHECK-LABEL: llhd.proc @Foo.always_ff.
// CHECK-NEXT:    br [[BB:\^.+]]
// CHECK-NEXT:  [[BB]]:
// CHECK-NEXT:    br [[BB]]
// CHECK-NEXT:  }

// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    [[PRB:%.+]] = llhd.prb
// CHECK-NEXT:    [[ZERO:%.+]] = hw.constant 0 : i3
// CHECK-NEXT:    comb.sub [[ZERO]], [[PRB]]
// CHECK-NEXT:    [[PRB:%.+]] = llhd.prb
// CHECK-NEXT:    [[ONES:%.+]] = hw.constant -1 : i3
// CHECK-NEXT:    comb.xor [[ONES]], [[PRB]]
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }

// `if`
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:  [[PRB:%.+]] = llhd.prb
// CHECK-NEXT:    [[FALSE:%.+]] = hw.constant false
// CHECK-NEXT:    [[CMP:%.+]] = comb.icmp ne [[PRB]], [[FALSE]]
// CHECK-NEXT:    cond_br [[CMP]], [[IF_TRUE:\^.+]], [[IF_FALSE:\^.+]]
// CHECK-NEXT:  [[IF_TRUE]]:
// CHECK-NEXT:    br [[IF_EXIT:\^.+]]
// CHECK-NEXT:  [[IF_FALSE]]:
// CHECK-NEXT:    br [[IF_EXIT:\^.+]]
// CHECK-NEXT:  [[IF_EXIT]]:
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }

// `repeat` loop
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    [[TMP:%.+]] = hw.constant 10
// CHECK-NEXT:    [[VAR:%.+]] = llhd.var [[TMP]]
// CHECK-NEXT:    br [[BB_CHECK:\^.+]]
// CHECK-NEXT:  [[BB_CHECK]]:
// CHECK-NEXT:    [[TMP:%.+]] = llhd.load [[VAR]]
// CHECK-NEXT:    [[ZERO:%.+]] = hw.constant 0
// CHECK-NEXT:    [[CMP:%.+]] = comb.icmp ne [[TMP]], [[ZERO]]
// CHECK-NEXT:    cond_br [[CMP]], [[BB_BODY:\^.+]], [[BB_EXIT:\^.+]]
// CHECK-NEXT:  [[BB_EXIT]]:
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  [[BB_BODY]]:
// CHECK-NEXT:    [[TMP:%.+]] = llhd.load [[VAR]]
// CHECK-NEXT:    [[ONE:%.+]] = hw.constant 1
// CHECK-NEXT:    [[REST:%.+]] = comb.sub [[TMP]], [[ONE]]
// CHECK-NEXT:    llhd.store [[VAR]], [[REST]]
// CHECK-NEXT:    br [[BB_CHECK]]
// CHECK-NEXT:  }

// `while` loop
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    br [[BB_CHECK:\^.+]]
// CHECK-NEXT:  [[BB_CHECK]]:
// CHECK-NEXT:    [[TMP:%.+]] = llhd.prb
// CHECK-NEXT:    [[FALSE:%.+]] = hw.constant false
// CHECK-NEXT:    [[CMP:%.+]] = comb.icmp ne [[TMP]], [[FALSE]]
// CHECK-NEXT:    cond_br [[CMP]], [[BB_BODY:\^.+]], [[BB_EXIT:\^.+]]
// CHECK-NEXT:  [[BB_EXIT]]:
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  [[BB_BODY]]:
// CHECK-NEXT:    br [[BB_CHECK]]
// CHECK-NEXT:  }

// `do-while` loop
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    br [[BB_BODY:\^.+]]
// CHECK-NEXT:  [[BB_BODY]]:
// CHECK-NEXT:    [[TMP:%.+]] = llhd.prb
// CHECK-NEXT:    [[FALSE:%.+]] = hw.constant false
// CHECK-NEXT:    [[CMP:%.+]] = comb.icmp ne [[TMP]], [[FALSE]]
// CHECK-NEXT:    cond_br [[CMP]], [[BB_BODY:\^.+]], [[BB_EXIT:\^.+]]
// CHECK-NEXT:  [[BB_EXIT]]:
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }

// `for` loop
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    br [[BB_CHECK:\^.+]]
// CHECK-NEXT:  [[BB_CHECK]]:
// CHECK-NEXT:    [[TMP:%.+]] = llhd.prb
// CHECK-NEXT:    cond_br [[TMP]], [[BB_BODY:\^.+]], [[BB_EXIT:\^.+]]
// CHECK-NEXT:  [[BB_EXIT]]:
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  [[BB_BODY]]:
// CHECK-NEXT:    {{%.+}} = hw.constant 42
// CHECK-NEXT:    br [[BB_CHECK:\^.+]]
// CHECK-NEXT:  }

// `forever` loop
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    br [[BB_BODY:\^.+]]
// CHECK-NEXT:  [[BB_BODY]]:
// CHECK-NEXT:    {{%.+}} = hw.constant 42
// CHECK-NEXT:    br [[BB_BODY:\^.+]]
// CHECK-NEXT:  {{\^[^:]+}}:
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }

// `c = 42` assignment
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    [[TMP:%.+]] = llhd.prb [[SIG:%.+]] :
// CHECK-NEXT:    [[SHADOW:%.+]] = llhd.var [[TMP]]
// CHECK-NEXT:    [[VALUE:%.+]] = hw.constant 42
// CHECK-NEXT:    [[DELAY:%.+]] = llhd.constant_time #llhd.time<0ps, 0d, 1e>
// CHECK-NEXT:    llhd.drv [[SIG]], [[VALUE]] after [[DELAY]]
// CHECK-NEXT:    llhd.store [[SHADOW]], [[VALUE]]
// CHECK-NEXT:    llhd.load [[SHADOW]]
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }

// `c <= 42` assignment
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    [[TMP:%.+]] = llhd.prb [[SIG:%.+]] :
// CHECK-NEXT:    [[SHADOW:%.+]] = llhd.var [[TMP]]
// CHECK-NEXT:    [[DELAY:%.+]] = llhd.constant_time #llhd.time<0ps, 1d, 0e>
// CHECK-NEXT:    [[VALUE:%.+]] = hw.constant 42
// CHECK-NEXT:    llhd.drv [[SIG]], [[VALUE]] after [[DELAY]]
// CHECK-NOT:     llhd.store [[SHADOW]], [[VALUE]]
// CHECK-NEXT:    llhd.load [[SHADOW]]
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }

// `c <= #1ns 42` assignment
// CHECK-LABEL: llhd.proc @Foo.initial.
// CHECK-NEXT:    [[TMP:%.+]] = llhd.prb [[SIG:%.+]] :
// CHECK-NEXT:    [[SHADOW:%.+]] = llhd.var [[TMP]]
// CHECK-NEXT:    [[DELAY:%.+]] = llhd.constant_time #llhd.time<1000ps, 0d, 0e>
// CHECK-NEXT:    [[VALUE:%.+]] = hw.constant 42
// CHECK-NEXT:    llhd.drv [[SIG]], [[VALUE]] after [[DELAY]]
// CHECK-NOT:     llhd.store [[SHADOW]], [[VALUE]]
// CHECK-NEXT:    llhd.load [[SHADOW]]
// CHECK-NEXT:    llhd.halt
// CHECK-NEXT:  }
