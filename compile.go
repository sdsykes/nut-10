package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strings"
)

var doglang = map[string]string{"AWOO": "=", "GRRR": "while", "YIP": "<", "BOW": "do", "RUF?": "if", "YAP": ">", "VUH": "then", "BARK": "-", "ROWH": "else", "WOOF": "+", "ARF": "*", "ARRUF": "end", "BORF": "end"}

type Tokens struct {
	tokens   []string
	tokenPos int
}

func (t *Tokens) AddToken(s string) {
	t.tokens = append(t.tokens, s)
}
func (t *Tokens) Remain() bool {
	return len(t.tokens) > t.tokenPos
}
func (t *Tokens) Consume() string {
	t.tokenPos += 1
	return t.tokens[t.tokenPos-1]
}
func (t *Tokens) Unconsume() {
	t.tokenPos -= 1
}

func priority(operator string) int {
	return map[string]int{"*": 1, "+": 2, "-": 2, ">": 3, "<": 3}[operator]
}

type Node struct {
	nodeType   string
	subnodes   map[string]*Node
	statements []*Node
	value      string
}

func (n *Node) Lvalue() *Node {
	return n.subnodes["lvalue"]
}
func (n *Node) Rvalue() *Node {
	return n.subnodes["rvalue"]
}
func (n *Node) FixPrecedence() *Node {
	if n.Rvalue() != nil && priority(n.nodeType) <= priority(n.Rvalue().nodeType) {
		return makeLRNode(n.Rvalue().nodeType, makeLRNode(n.nodeType, n.Lvalue(), n.Rvalue().Lvalue()).FixPrecedence(), n.Rvalue().Rvalue())
	} else {
		return n
	}
}

func makeLRNode(nodeType string, lvalue *Node, rvalue *Node) *Node {
	return &Node{nodeType, map[string]*Node{"lvalue": lvalue, "rvalue": rvalue}, nil, ""}
}

func parseBlock(tokens *Tokens) *Node {
	var statements []*Node
	for tokens.Remain() {
		token := tokens.Consume()
		symbol := doglang[token]
		if symbol == "end" || symbol == "else" {
			break
		}
		var statement *Node
		switch symbol {
		case "=":
			lvalue := statements[len(statements)-1]
			statements = statements[:len(statements)-1]
			statement = makeLRNode("assign", lvalue, parseExpression(tokens))
		case "if":
			statement = &Node{"if", map[string]*Node{"condition": parseExpression(tokens), "then": parseBlock(tokens), "else": parseBlock(tokens)}, nil, ""}
		case "while":
			statement = &Node{"while", map[string]*Node{"condition": parseExpression(tokens), "do": parseBlock(tokens)}, nil, ""}
		default:
			statement = &Node{"identifier", nil, nil, token}
		}
		statements = append(statements, statement)
	}
	return &Node{"statements", nil, statements, ""}
}

func parseExpression(tokens *Tokens) *Node {
	var expression *Node
	for tokens.Remain() {
		token := tokens.Consume()
		symbol := doglang[token]
		numeric, _ := regexp.MatchString("^[0-9]+$", token)
		if numeric {
			expression = &Node{"integer", nil, nil, token}
		} else if symbol == "" {
			if expression != nil {
				tokens.Unconsume()
				break
			}
			expression = &Node{"identifier", nil, nil, token}
		} else if priority(symbol) != 0 {
			expression = makeLRNode(symbol, expression, parseExpression(tokens))
		} else {
			tokens.Unconsume()
			break
		}
		expression = expression.FixPrecedence()
	}
	return expression
}

type State struct {
	registers map[string]bool
	varMap    map[string]int
}

var state *State

func (s *State) WithReg(node *Node, f func(r string) []string) []string {
	var asm []string
	for reg, used := range s.registers {
		if !used {
			s.registers[reg] = true
			asm = append(node.Lvalue().PrintNode(), fmt.Sprintf("movq %%rax, %s", reg))
			asm = append(asm, node.Rvalue().PrintNode()...)
			asm = append(asm, f(reg)...)
			s.registers[reg] = false
			break
		}
	}
	return asm
}

func generate(ast *Node) []string {
	state = &State{map[string]bool{"%rcx": false, "%rsi": false, "%rdi": false, "%r8": false, "%r9": false, "%r10": false, "%r11": false, "%r12": false}, make(map[string]int)}
	asm := []string{
		".text",
		".global _main",
		".global main",
		"_main:",
		"main:",
		"pushq %rbp",
		"movq %rsp, %rbp",
	}
	asm = append(asm, ast.PrintNode()...)
	asm = append(asm,
		"call print",
		"movq %rbp, %rsp",
		"popq %rbp",
		"ret",
	)
	return asm
}

func (node *Node) PrintNode() []string {
	var asm []string
	if node.nodeType == "statements" {
		for _, statement := range node.statements {
			asm = append(asm, statement.PrintNode()...)
		}
		return asm
	}
	node_id := fmt.Sprintf("%p", node)
	switch node.nodeType {
	case "assign":
		if state.varMap[node.Lvalue().value] != 0 {
			asm = append(
				node.Rvalue().PrintNode(),
				fmt.Sprintf("movq %%rax, %d(%%rbp)", state.varMap[node.Lvalue().value]),
			)
		} else {
			state.varMap[node.Lvalue().value] = len(state.varMap)*-8 - 8
			asm = append(
				node.Rvalue().PrintNode(),
				"pushq %rax",
			)
		}
	case "integer":
		asm = append(asm, fmt.Sprintf("movq $%s, %%rax", node.value))
	case "identifier":
		asm = append(asm, fmt.Sprintf("movq %d(%%rbp), %%rax", state.varMap[node.value]))
	case "+":
		asm = state.WithReg(node, func(r string) []string {
			return []string{fmt.Sprintf("addq %s, %%rax", r)}
		})
	case "-":
		asm = state.WithReg(node, func(r string) []string {
			return []string{
				fmt.Sprintf("xchg %%rax, %s", r),
				fmt.Sprintf("subq %s, %%rax", r),
			}
		})
	case "*":
		asm = state.WithReg(node, func(r string) []string {
			return []string{fmt.Sprintf("mulq %s", r)}
		})
	case "<":
		asm = state.WithReg(node, func(r string) []string {
			return []string{fmt.Sprintf(
				"cmpq %%rax, %s", r),
				"movq $1, %rax",
				fmt.Sprintf("jl lt%s", node_id),
				"movq $0, %rax",
				fmt.Sprintf("lt%s:", node_id),
			}
		})
	case ">":
		asm = state.WithReg(node, func(r string) []string {
			return []string{
				fmt.Sprintf("cmpq %%rax, %s", r),
				"movq $1, %rax",
				fmt.Sprintf("jg gt%s", node_id),
				"movq $0, %rax",
				fmt.Sprintf("gt%s:", node_id),
			}
		})
	case "if":
		asm = append(node.subnodes["condition"].PrintNode(), "cmpq $0, %rax", fmt.Sprintf("je else%s", node_id))
		asm = append(asm, node.subnodes["then"].PrintNode()...)
		asm = append(asm, fmt.Sprintf("jmp endif%s", node_id), fmt.Sprintf("else%s:", node_id))
		asm = append(asm, node.subnodes["else"].PrintNode()...)
		asm = append(asm, fmt.Sprintf("endif%s:", node_id))
	case "while":
		asm = append([]string{fmt.Sprintf("while%s:", node_id)}, node.subnodes["condition"].PrintNode()...)
		asm = append(asm, "cmpq $0, %rax", fmt.Sprintf("je endwhile%s", node_id))
		asm = append(asm, node.subnodes["do"].PrintNode()...)
		asm = append(asm, fmt.Sprintf("jmp while%s", node_id), fmt.Sprintf("endwhile%s:", node_id))
	}
	return asm
}

func main() {
	tokens := &Tokens{make([]string, 0), 0}
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Split(bufio.ScanWords)
	for scanner.Scan() {
		tokens.AddToken(scanner.Text())
		if err := scanner.Err(); err != nil {
			fmt.Fprintln(os.Stderr, "reading standard input:", err)
		}
	}

	ast := parseBlock(tokens)
	fmt.Println(strings.Join(generate(ast), "\n"))
}
