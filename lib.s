.text
  .global print

print:                   # print a positive integer
  pushq %rbp
  movq %rsp, %rbp

  movq %rbp, %rsi        # current addr

  dec %rsi
  movb $10, %dl          # newline
  movb %dl, (%rsi)
  movq $1, %rdi          # len
  
loop:
  movq $10, %rcx         # divide by 10, remainder is next digit
  movq $0, %rdx
  divq %rcx
  orq $0x30, %rdx        # make into ascii
  
  dec %rsi               # store
  movb %dl, (%rsi)
  inc %rdi

  cmpq $0, %rax
  jnz loop
  
  movq $0x2000004, %rax  # mac print syscall
  movq %rdi, %rdx        # len
  movq $1, %rdi          # stdout
  syscall

  movq $1, %rax          # linux print syscall
  syscall

  movq %rbp, %rsp
  popq %rbp
  ret
