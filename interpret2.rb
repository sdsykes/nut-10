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
  statements.compact
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

def interpret(node, variables)
  if node.is_a? Array
    return node.reduce(nil) {|_, subnode| interpret(subnode, variables)}
  end

  case node[:type]
  when :assign
    variables[node[:lvalue][:value]] = interpret(node[:rvalue], variables)
  when :integer
    node[:value]
  when :identifier
    variables[node[:value]]
  when :plus
    interpret(node[:lvalue], variables) + interpret(node[:rvalue], variables)
  when :minus
    interpret(node[:lvalue], variables) - interpret(node[:rvalue], variables)
  when :times
    interpret(node[:lvalue], variables) * interpret(node[:rvalue], variables)
  when :lt
    interpret(node[:lvalue], variables) < interpret(node[:rvalue], variables)
  when :gt
    interpret(node[:lvalue], variables) > interpret(node[:rvalue], variables)
  when :if
    if interpret(node[:condition], variables)
      interpret(node[:then], variables)
    else
      interpret(node[:else], variables)
    end
  when :while
    while interpret(node[:condition], variables)
      interpret(node[:do], variables)
    end
  end
end

puts interpret(parse_block(Tokens.new), {})
