runner = case ARGV[0]
when 'interpret'
  Proc.new {|file| `ruby interpret.rb #{file}`}
when 'interpret2'
  Proc.new {|file| `ruby interpret2.rb #{file}`}
when 'compile_ruby'
  Proc.new {|file| `ruby compile.rb #{file} | cc -x assembler - lib.s; ./a.out`}
when 'compile_go'
  `go build compile.go`
  Proc.new {|file| `./compile <#{file} | cc -x assembler - lib.s; ./a.out`}
end

abort("Specify interpret, interpret2, compile_ruby or compile_go") if runner.nil?

files = ["test1.doggolang", "test2.doggolang", "test3.doggolang", "test4.doggolang", "samantha.doggolang", "precedence.doggolang"]
results = [11, 15, 105, 19, 64185, 23]

0.upto(files.size - 1) do |n|
  result = runner.call(files[n])
  if result.to_i == results[n]
    puts "PASS #{n + 1}"
  else
    puts "FAIL #{n + 1} (expected #{results[n]} got #{result.to_i})"
  end
end
