%option noyywrap nounput noinput

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"

int line_no   = 1;
int col_no    = 1;
int lex_errors = 0;

#define YY_USER_ACTION                          \
    yylloc.first_line   = line_no;              \
    yylloc.first_column = col_no;               \
    yylloc.last_line    = line_no;              \
    yylloc.last_column  = col_no + yyleng - 1;  \
    col_no += yyleng;

#define STR_MAX 1024
static char strbuf[STR_MAX];
static int  strlen_ = 0;
static int  str_line, str_col;

static void str_add(char c) {
    if (strlen_ < STR_MAX - 1) strbuf[strlen_++] = c;
}

static void lex_error(const char *msg, const char *text) {
    fprintf(stderr, "lexical error at %d:%d: %s%s%s\n",
            line_no, col_no - (int)strlen(text), msg,
            text[0] ? " " : "", text);
    lex_errors++;
}
%}

DIGIT       [0-9]
ID_START    [A-Za-z_$]
ID_PART     [A-Za-z0-9_$]
EXP         [eE][+-]?{DIGIT}+

%x COMMENT
%x STR

%%

[ \t\r]+                { }
\n                      { line_no++; col_no = 1; }

"//".*                  { }
"/*"                    { BEGIN(COMMENT); }
<COMMENT>"*/"           { BEGIN(INITIAL); }
<COMMENT>\n             { line_no++; col_no = 1; }
<COMMENT>[^*\n]+        { }
<COMMENT>"*"            { }
<COMMENT><<EOF>>        { lex_error("unterminated block comment", ""); BEGIN(INITIAL); return 0; }

"let"                   { return LET; }
"const"                 { return CONST; }
"function"              { return FUNCTION; }
"if"                    { return IF; }
"else"                  { return ELSE; }
"while"                 { return WHILE; }
"for"                   { return FOR; }
"return"                { return RETURN; }
"break"                 { return BREAK; }
"continue"              { return CONTINUE; }
"true"                  { return TRUE; }
"false"                 { return FALSE; }
"null"                  { return NULL_T; }
"undefined"             { return UNDEFINED; }

"var"|"class"|"new"|"this"|"try"|"catch"|"throw"|"switch"|"do"|"async"|"await"|"typeof"|"delete" {
    lex_error("keyword not supported in EMJS:", yytext);
}

{DIGIT}+"."{DIGIT}*({EXP})?     { yylval.num = atof(yytext); return NUMBER; }
"."{DIGIT}+({EXP})?             { yylval.num = atof(yytext); return NUMBER; }
{DIGIT}+({EXP})?                { yylval.num = atof(yytext); return NUMBER; }
"0"[xX][0-9a-fA-F]+             { yylval.num = (double)strtoul(yytext, NULL, 16); return NUMBER; }

{ID_START}{ID_PART}*    { yylval.str = strdup(yytext); return IDENT; }

\"                      { BEGIN(STR); strlen_ = 0; str_line = line_no; str_col = col_no - 1; }
<STR>\"                 {
                            BEGIN(INITIAL);
                            strbuf[strlen_] = '\0';
                            yylval.str = strdup(strbuf);
                            return STRING;
                        }
<STR>\\n                { str_add('\n'); }
<STR>\\t                { str_add('\t'); }
<STR>\\r                { str_add('\r'); }
<STR>\\0                { str_add('\0'); }
<STR>\\\\               { str_add('\\'); }
<STR>\\\"               { str_add('"'); }
<STR>\\.                { lex_error("invalid escape sequence", yytext); }
<STR>\n                 {
                            lex_error("newline inside string literal", "");
                            line_no++; col_no = 1;
                            BEGIN(INITIAL);
                        }
<STR>[^\\\"\n]+         { for (int i = 0; i < yyleng; i++) str_add(yytext[i]); }
<STR><<EOF>>            { lex_error("unterminated string literal", ""); BEGIN(INITIAL); return 0; }

"==="                   { return EQ_EQ_EQ; }
"!=="                   { return NOT_EQ_EQ; }
"=="                    { return EQ_EQ; }
"!="                    { return NOT_EQ; }
"<="                    { return LESS_EQ; }
">="                    { return GREATER_EQ; }
"&&"                    { return AND; }
"||"                    { return OR; }
"++"                    { return INC; }
"--"                    { return DEC; }
"+="                    { return PLUS_ASSIGN; }
"-="                    { return MINUS_ASSIGN; }
"*="                    { return STAR_ASSIGN; }
"/="                    { return SLASH_ASSIGN; }

[+\-*/%=<>!(){}\[\];,.:]  { return yytext[0]; }

.                       { lex_error("unexpected character", yytext); }

%%
