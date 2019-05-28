# Doggolang (Wundernut 10)

## Problem

Reverse engineer Doggolang from example code and example results. This turns out to be a relatively easy task, as the Doggolang keywords map pretty simply to a straightforward imperative language. The simplest interpreter I could come up with is just a single line of Ruby:

```ruby
puts eval($<.read.gsub(/[A-Z?]+/, "AWOO"=>"=", 'GRRR'=>"while", "YIP"=>"<", "BOW"=>"do", "RUF?"=>"if", "YAP"=>">", "VUH"=>"then", "BARK"=>"-", "ROWH"=>"else", "WOOF"=>"+", "ARF"=>"*", "ARRUF"=>"end", "BORF"=>"end"))
```

I wrote a simple test harness with the 4 example programs, and added the challenge program (samantha.doggolang) to the tests as the 5th once the result was known.

```
$ ruby test.rb 
PASS 1
PASS 2
PASS 3
PASS 4
PASS 5
```

This seemed too easy. I wonder...

In Doggolang we don't have to worry about operator precedence, if-then without an else, any kind of compound expressions, there is an extremely limited set of available operations, no globals, no strings, and all variables are ints, positive ones at that. In short it's almost the simplest turing-complete language you can imagine.

Could I write a compiler for Doggolang? Am I insane?

Let's get started.

Input will be Doggolang source code, output will be x86_64 assembly. Then we can pass it to the system assembler and loader, orchestrated by cc.

Strategy is as follows:

1. Tokenize.
2. Parse into an abstract syntax tree.
3. Generate code from that.

#### Tokenization
Tokenization of Doggolang is a case of just splitting on whitespace. For my own sanity at this point I also map all the Doggolang keywords like GRRR to a symbol for while, RUF? to a symbol for if and so on. No further annotation of the tokens is necessary, as we have already recognised the keywords.

#### Parse
A simple recursive descent parser. The rules for Doggolang indicate that everything is either a "block" (which is a sequence of statements), a "statement" (which is an assignment or an if or while, or a plain variable name for the final value), or an "expression" (which gives a numerical or boolean result).

The whole program is in fact a block, so all we need to do is call parse_block and this should return the complete syntax tree. All in all the parsing is not complex, and is achieved in less than 60 lines of code. Initially I did not support operator precedence as none of the examples would be affected by it, but it wasn't that hard to add and I am happier with the result.

#### Generate
The code generator walks the ast and generates a small amount of assembly for each node.

The first problem is how to store variables, but we have no globals to worry about, so let's just push them on the stack. We take care to record the address offset of each of them.

The second problem is to make sure we can store values temporarily when doing arithmetic and comparison operations. We'll use registers for this. In fact none of the examples need more than one register, but anyway we can take care to choose an available register, and to mark it in use so that nested operations can work. At some point you will run out of registers though, this is a limitation.

With this taken care of, the code generator walks each node and produces a list of assembly commands.

Finally, we need to print the result, For this I wrote a simple routine to print a positive integer, which is the only function in the compiler's library, the file lib.s. The call to this is added to the end of the assembly, then it's ready.

The code generator is the perhaps the hardest part of this compiler to write, and weighs about 100 lines of code.

With a small amount of care the generated assembly will work both on Mac and Linux.

And finally (and after admittedly a fair bit of debugging) it does in fact work:

```
$ ruby test.rb 
PASS 1
PASS 2
PASS 3
PASS 4
PASS 5
```

The whole compiler is approximately 175 SLOC.

#### Performance

Once you have compiled the Doggolang source code, the execution should be crazy fast, there isn't a lot of wastage in the assembler output (although an optimisation step could of course improve things further).

Let's benchmark it. I have a short program (based on samantha) set up to loop 100 million times. First with the interpreter:

```
$ time ruby interpret.rb benchmark.doggolang 
8

real	0m5.456s
user	0m5.289s
sys	0m0.065s
```

Then the compiled version:

```
$ ruby compile.rb benchmark.doggolang | cc -x assembler - lib.s
$ time ./a.out
8

real	0m0.423s
user	0m0.418s
sys	0m0.003s
```

The ruby interpreter is pretty good, but the compiled version runs in about one thirteenth of the time.

## The answer

```
$ ruby interpret.rb samantha.doggolang 
64185
$ ruby compile.rb samantha.doggolang | cc -x assembler - lib.s; ./a.out
64185
```

So the answer is 64185.
