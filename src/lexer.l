%option noyywrap
 
%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    int lineno = 1; // initialize to 1
    void print(char *token_type);
    void yyerror();
%}
 
%x ML_COMMENT
 
alpha       [a-zA-Z]
digit       [0-9]
alnum       {alpha}|{digit}
print       [ -~]
 
ID          {alpha}+{alnum}*
INT         "0"|[0-9]{digit}*
FLOAT       "0"|{digit}*"."{digit}+
STRING      \"{print}*\"
 
%%
 
"//".*                  { printf("Eat up comment at line %d\n", lineno); } 
 
"/*"                    { printf("Eat up comment from line %d ", lineno); BEGIN(ML_COMMENT); }
<ML_COMMENT>"*/"        { printf("to line %d\n", lineno); BEGIN(INITIAL); }
<ML_COMMENT>"\n"        { lineno += 1; }
 
 
"INT"           { print("KEYWORD_INT"); }
"FLOAT"         { print("KEYWORD_FLOAT"); }
"STRING"        { print("KEYWORD_STRING"); }
"IF"            { print("KEYWORD_IF"); }
"ELSE"          { print("KEYWORD_ELSE"); }
 
 
"+"             { print("ADDOP"); }
"-"             { print("SUBOP"); }
"*"             { print("MULOP"); }
"/"             { print("DIVOP"); }
"++"|"--"       { print("INCR"); }
 
 
"("             { print("LPAREN"); }
")"             { print("RPAREN"); }
"."             { print("DOT"); }
","             { print("COMMA"); }
"="             { print("ASSIGN"); }
 
 
{ID}            { print("ID"); }
{INT}           { print("INT"); }
{FLOAT}         { print("FLOAT"); }
{STRING}        { print("STRING"); }
 
 
"\n"            { lineno += 1; }
[ \t\r\f]+          /* eat up whitespace */
 
.               { yyerror("Unrecognized character"); }
 
%%
 
void print(char *token_type){
    printf("yytext: %s\ttoken: %s\tlineno: %d\n", yytext, token_type, lineno);
}
 
void yyerror(char *message){
    printf("Error: \"%s\" in line %d. Token = %s\n", message, lineno, yytext);
    exit(1);
}
 
int main(int argc, char *argv[]){
    yyin = fopen(argv[1], "r");
    yylex();
    fclose(yyin);
    return 0;
}