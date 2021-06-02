%{
	#include "node.h"
        #include <cstdio>
        #include <cstdlib>
	Block *programBlock; /* the top level root node of our final AST */

	extern int yylex();
	void yyerror(const char *s) { std::printf("Error: %s\n", s);std::exit(1); }
%}

/* Represents the many different ways we can access our data */
%union {
	Node *node;
	Block *block;
	Expression *expr;
	Statement *stmt;
	Identifier *ident;
	VariableDeclaration *var_decl;
	std::vector<VariableDeclaration*> *varvec;
	std::vector<Expression*> *exprvec;
	std::string *string;
	int token;
}

/* Define our terminal symbols (tokens). This should
   match our tokens.l lex file. We also define the node type
   they represent.
 */
%token <string> TIDENTIFIER TINTEGER TDOUBLE
%token <token> TCEQ TCNE TCLT TCLE TCGT TCGE TEQUAL
%token <token> TLPAREN TRPAREN TLBRACE TRBRACE TCOMMA TDOT
%token <token> TPLUS TMINUS TMUL TDIV
%token <token> TRETURN TEXTERN

/* Define the type of node our nonterminal symbols represent.
   The types refer to the %union declaration above. Ex: when
   we call an ident (defined by union type ident) we are really
   calling an (NIdentifier*). It makes the compiler happy.
 */
%type <ident> ident
%type <expr> numeric expr 
%type <varvec> func_decl_args
%type <exprvec> call_args
%type <block> program stmts block
%type <stmt> stmt var_decl func_decl extern_decl
%type <token> comparison

/* Operator precedence for mathematical operators */
%left TPLUS TMINUS
%left TMUL TDIV

%start program

%%

program: stmts { programBlock = $1; } ;
		
ident: TIDENTIFIER { $$ = new Identifier(*$1); delete $1; } ;

stmts: stmt { $$ = new Block(); $$->statements.push_back($<stmt>1); } | 
	stmts stmt { $1->statements.push_back($<stmt>2); }
;

stmt: var_decl | func_decl | extern_decl
	 | expr { $$ = new ExpressionStatement(*$1); }
	 | TRETURN expr { $$ = new ReturnStatement(*$2); }
     ;

block: TLBRACE stmts TRBRACE { $$ = $2; }
	  | TLBRACE TRBRACE { $$ = new Block(); }
	  ;

var_decl: ident ident { $$ = new VariableDeclaration(*$1, *$2); }
		 | ident ident TEQUAL expr { $$ = new VariableDeclaration(*$1, *$2, $4); }
		 ;

extern_decl: TEXTERN ident ident TLPAREN func_decl_args TRPAREN
                { $$ = new ExternDeclaration(*$2, *$3, *$5); delete $5; }
            ;

func_decl: ident ident TLPAREN func_decl_args TRPAREN block 
			{ $$ = new FunctionDeclaration(*$1, *$2, *$4, *$6); delete $4; } 	
		  ;
	
func_decl_args: /*blank*/  { $$ = new VariableList(); }
		  | var_decl { $$ = new VariableList(); $$->push_back($<var_decl>1); }
		  | func_decl_args TCOMMA var_decl { $1->push_back($<var_decl>3); }
		  ;



numeric: TINTEGER { $$ = new Integer(atol($1->c_str())); delete $1; }
		| TDOUBLE { $$ = new Double(atof($1->c_str())); delete $1; }
		;
	
expr: ident TEQUAL expr { $$ = new Assignment(*$<ident>1, *$3); }
	 | ident TLPAREN call_args TRPAREN { $$ = new FunctionCall(*$1, *$3); delete $3; }
	 | ident { $<ident>$ = $1; }
	 | numeric
         | expr TMUL expr { $$ = new BinaryOp(*$1, "*", *$3); }
         | expr TDIV expr { $$ = new BinaryOp(*$1, "/", *$3); }
         | expr TPLUS expr { $$ = new BinaryOp(*$1, "+", *$3); }
         | expr TMINUS expr { $$ = new BinaryOp(*$1, "-", *$3); }
     | TLPAREN expr TRPAREN { $$ = $2; }
	 ;
	
call_args: /*blank*/  { $$ = new ExpressionList(); }
		  | expr { $$ = new ExpressionList(); $$->push_back($1); }
		  | call_args TCOMMA expr  { $1->push_back($3); }
		  ;
		  
%%
