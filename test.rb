runner = case ARGV[0]
when 'interpret'
  Proc.new {|file| `ruby interpret.rb #{file}`}
when 'ruby'
  Proc.new {|file| `ruby compile.rb #{file} | cc -x assembler - lib.s; ./a.out`}
when 'go'
  Proc.new {|file| `go run compile.go <#{file} | cc -x assembler - lib.s; ./a.out`}
end

abort("Specify interpret, ruby or go") if runner.nil?

files = ["test1.doggolang", "test2.doggolang", "test3.doggolang", "test4.doggolang", "samantha.doggolang", "precedence.doggolang"]
results = [11, 15, 105, 19, 64185, 42]

0.upto(files.size - 1) do |n|
  result = runner.call(files[n])
  if result.to_i == results[n]
    puts "PASS #{n + 1}"
  else
    puts "FAIL #{n + 1} (expected #{results[n]} got #{result.to_i})"
  end
end
