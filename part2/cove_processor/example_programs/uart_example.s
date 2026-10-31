	.file	"uart_example.s"
	.option nopic
	.text
	.align	3
  .global _start
  .global main
_start:
main:
	addi	zero,zero,0
	addi	ra,zero,0
  # Set a stack Pointer
  li    sp,0x2000
	addi	gp,zero,0
	addi	tp,zero,0
	addi	t0,zero,0
	addi	t1,zero,0
	addi	t2,zero,0
	addi	s0,zero,0
	addi	a0,zero,0
	addi	a1,zero,0
	addi	a2,zero,0
	addi	a3,zero,0
	addi	a3,zero,0
	addi	a4,zero,0
  # a5: UART TX_ADDR - Writes to this address are sent out the UART as data.
  li a5, 0xC0020
	addi	a6,zero,0
	addi	a7,zero,0
	addi	s2,zero,0
	addi	s3,zero,0
	addi	s4,zero,0
	addi	s5,zero,0
	addi	s6,zero,0
	addi	s7,zero,0
	addi	s8,zero,0
	addi	s9,zero,0
	addi	s10,zero,0
	addi	s11,zero,0
	addi	t3,zero,0
	addi	t4,zero,0
	addi	t5,zero,0
	addi	t6,zero,0

# Write the string out the UART
print_hello:
  # Set string pointer variable
  la t5, .LC0
  # Load first charachter in string
  lbu   t6,0(t5)
  jal   zero,rdy_while_condition
rdy_while_top:
  # Write to UART tx
  sb    t6,0(a5)
  # Increment string pointer
  addi  t5,t5,1
  # Load next charachter
  lbu   t6,0(t5)
rdy_while_condition:
  bne   t6,zero,rdy_while_top

end:
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  # Loop forever
  j end

	.section	.rodata
	.align	2
.LC0:
	.string	"\nHello World!\n"
	.align	3


