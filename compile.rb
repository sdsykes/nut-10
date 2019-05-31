DOGLANG = {"AWOO"=>:"=", 'GRRR'=>:while, "YIP"=>:"<", "BOW"=>:do, "RUF?"=>:if, "YAP"=>:">", "VUH"=>:then, "BARK"=>:"-", "ROWH"=>:else, "WOOF"=>:"+", "ARF"=>:"*", "ARRUF"=>:end, "BORF"=>:end}

### Tokenize
class Tokens
  def initialize
    @tokens = $<.read.split(/\s+/).collect {|token| DOGLANG[token] || token}
    @token_pos = 0
  end

  def remain?
    @tokens.count > @token_pos
  end

  def consume
    @token_pos += 1
    @tokens[@token_pos - 1]
  end

  def unconsume
    @token_pos -= 1
  end
end

### Parse
def parse_block(tokens)
  statements = []
  while tokens.remain?
    token = tokens.consume
    if token == :end || token == :else
      break
    else
      statements << case token
      when String
        {type: :identifier, value: token}
      when :"="
        {type: :assign, lvalue: statements.pop, rvalue: parse_expression(tokens)}
      when :if
        {type: :if, condition: parse_expression(tokens), then: parse_block(tokens), else: parse_block(tokens)}
      when :while
        {type: :while, condition: parse_expression(tokens), do: parse_block(tokens)}
      else
        nil
      end
    end
  end
  statements
end

OPERATORS = {"+": :plus, "-": :minus, "*": :times, ">": :gt, "<": :lt}
HIGH_PRIORITY = 100

def priority(operator)
  {times: 3, minus: 2, plus: 2, gt: 1, lt: 1}[operator] || HIGH_PRIORITY
end

def fix_precedence(expression)
  # if the op on the right has lower or equal precedence, execute it after
  if expression.has_key?(:rvalue) && priority(expression[:type]) >= priority(expression[:rvalue][:type])
    expression = {
      type: expression[:rvalue][:type], 
      lvalue: fix_precedence({type: expression[:type], lvalue: expression[:lvalue], rvalue: expression[:rvalue][:lvalue]}), 
      rvalue: expression[:rvalue][:rvalue]
    }
  end
  expression
end

def parse_expression(tokens)
  expression = nil
  while tokens.remain?
    token = tokens.consume
    case token
    when /[0-9]+/
      expression = {type: :integer, value: token.to_i}
    when String
      if expression  # must be the start of a new identifier or assignment statement
        tokens.unconsume
        break
      end
      expression = {type: :identifier, value: token}
    else
      if OPERATORS.include?(token)
        expression = {type: OPERATORS[token], lvalue: expression, rvalue: parse_expression(tokens)}
      else  # must be the start of a new if or while statement
        tokens.unconsume
        break
      end
    end
    expression = fix_precedence(expression)
  end
  expression
end

### Generate code
class State
  attr_reader :var_map
  
  def initialize
    @registers = {"%rcx": true, "%rsi": true, "%rdi": true, "%r8": true, "%r9": true, "%r10": true, "%r11": true, "%r12": true}
    @var_map = {}
    @label_id = 0
  end
  
  def next_label_id
    @label_id += 1
  end
  
  def with_reg(node)
    register = @registers.detect {|name, available| available}[0]
    @registers[register] = false
    code = print_node(node[:lvalue], self) + ["movq %rax, #{register}"] + print_node(node[:rvalue], self) + yield(register)
    @registers[register] = true
    code
  end
end

def generate(ast)
  [
    ".text",
    ".global _main",
    ".global main",
    "_main:",
    "main:",
    "pushq %rbp",
    "movq %rsp, %rbp"
  ] + print_node(ast, State.new) + [
    "call print",
    "movq %rbp, %rsp",
    "popq %rbp",
    "ret"
  ]
end

def print_node(node, state)
  case node
  when nil
    return []
  when Array
    return node.collect{|subnode| print_node(subnode, state)}
  end

  label_id = state.next_label_id # used to uniquely identify branch labels
  
  case node[:type]
  when :assign
    if state.var_map[node[:lvalue][:value]]
      print_node(node[:rvalue], state) + ["movq %rax, #{state.var_map[node[:lvalue][:value]]}(%rbp)"]
    else
      # This sets the offset from rbp for this variable
      state.var_map[node[:lvalue][:value]] = state.var_map.count * -8 - 8
      print_node(node[:rvalue], state) + ["pushq %rax"]
    end
  when :integer
    ["movq $#{node[:value]}, %rax"]
  when :identifier
    ["movq #{state.var_map[node[:value]]}(%rbp), %rax"]
  when :plus
    state.with_reg(node) {|r| ["addq #{r}, %rax"]}
  when :minus
    state.with_reg(node) {|r| [
      "xchg %rax, #{r}",
      "subq #{r}, %rax"
    ]}
  when :times
    state.with_reg(node) {|r| ["mulq #{r}"]}
  when :lt
    state.with_reg(node) {|r| [
      "cmpq %rax, #{r}",
      "movq $1, %rax",
      "jl lt#{label_id}",
      "movq $0, %rax",
      "lt#{label_id}:"
    ]}
  when :gt
    state.with_reg(node) {|r| [
      "cmpq %rax, #{r}",
      "movq $1, %rax",
      "jg gt#{label_id}",
      "movq $0, %rax",
      "gt#{label_id}:"
    ]}
  when :if
    print_node(node[:condition], state) + [
      "cmpq $0, %rax",
      "je else#{label_id}"
    ] + print_node(node[:then], state) + [
      "jmp endif#{label_id}",
      "else#{label_id}:"
    ] + print_node(node[:else], state) + [
      "endif#{label_id}:"
    ]
  when :while
    [
      "while#{label_id}:"
    ] + print_node(node[:condition], state) + [
      "cmpq $0, %rax",
      "je endwhile#{label_id}"
    ] + print_node(node[:do], state) + [
      "jmp while#{label_id}",
      "endwhile#{label_id}:"
    ]
  else
    []
  end
end

puts generate(parse_block(Tokens.new))
