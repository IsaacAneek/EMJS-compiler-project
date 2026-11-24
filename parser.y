%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define KIND_NUM    1
#define KIND_VAR    2
#define KIND_BINOP  3
#define KIND_UNOP   4
#define KIND_CALL   5
#define KIND_ASSIGN 6
#define KIND_INC    7
#define KIND_DEC    8
#define KIND_LET    9
#define KIND_IF     10
#define KIND_FOR    11
#define KIND_RETURN 12
#define KIND_FUNC   13

int  yylex(void);
void yyerror(const char *msg);
extern FILE *yyin;

typedef struct Node {
    int kind;
    int op;
    int val;
    char name[32];
    char p1[32];
    char p2[32];
    struct Node *left;
    struct Node *right;
    struct Node *cond;
    struct Node *step;
    struct Node *body;
    struct Node *next;
} Node;

static Node *root = NULL;

static Node *make_num(int val) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_NUM;
    n->val = val;
    return n;
}

static Node *make_var(char *name) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_VAR;
    strncpy(n->name, name, 31);
    return n;
}

static Node *make_binop(int op, Node *l, Node *r) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_BINOP;
    n->op = op;
    n->left = l;
    n->right = r;
    return n;
}

static Node *make_unop(int op, Node *l) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_UNOP;
    n->op = op;
    n->left = l;
    return n;
}

static Node *make_call2(char *name, Node *a1, Node *a2) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_CALL;
    strncpy(n->name, name, 31);
    n->left = a1;
    n->right = a2;
    return n;
}

static Node *make_call1(char *name, Node *a1) {
    return make_call2(name, a1, NULL);
}

static Node *make_call0(char *name) {
    return make_call2(name, NULL, NULL);
}

static Node *make_assign(int op, char *name, Node *val) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_ASSIGN;
    n->op = op;
    strncpy(n->name, name, 31);
    n->left = val;
    return n;
}

static Node *make_inc(int prefix, char *name) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_INC;
    n->val = prefix;
    strncpy(n->name, name, 31);
    return n;
}

static Node *make_dec(int prefix, char *name) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_DEC;
    n->val = prefix;
    strncpy(n->name, name, 31);
    return n;
}

static Node *make_let(char *name, Node *init) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_LET;
    strncpy(n->name, name, 31);
    n->left = init;
    return n;
}

static Node *make_if(Node *cond, Node *then_b, Node *else_b) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_IF;
    n->cond = cond;
    n->body = then_b;
    n->right = else_b;
    return n;
}

static Node *make_for(Node *init, Node *cond, Node *step, Node *body) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_FOR;
    n->left = init;
    n->cond = cond;
    n->step = step;
    n->body = body;
    return n;
}

static Node *make_return(Node *expr) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_RETURN;
    n->left = expr;
    return n;
}

static Node *make_func(char *name, char *p1, char *p2, Node *body) {
    Node *n = (Node *)calloc(1, sizeof(Node));
    n->kind = KIND_FUNC;
    strncpy(n->name, name, 31);
    strncpy(n->p1, p1, 31);
    strncpy(n->p2, p2, 31);
    n->body = body;
    return n;
}

static Node *append_node(Node *list, Node *n) {
    if (!list) return n;
    Node *cur = list;
    while (cur->next) cur = cur->next;
    cur->next = n;
    return list;
}
%}

%locations

%union {
    double num;
    char  *str;
    struct Node *node;
}

%token <num> NUMBER
%token <str> IDENT STRING
%token LET CONST FUNCTION IF ELSE WHILE FOR RETURN BREAK CONTINUE
%token TRUE FALSE NULL_T UNDEFINED
%token EQ_EQ NOT_EQ EQ_EQ_EQ NOT_EQ_EQ LESS_EQ GREATER_EQ AND OR
%token INC DEC PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN

%type <node> program stmt_list stmt func_decl for_init opt_expr expr

%precedence LOWER_THAN_ELSE
%precedence ELSE

%right '=' PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN
%left  OR
%left  AND
%left  EQ_EQ NOT_EQ EQ_EQ_EQ NOT_EQ_EQ
%left  '<' '>' LESS_EQ GREATER_EQ
%left  '+' '-'
%left  '*' '/' '%'
%precedence UMINUS '!'
%precedence INC DEC

%%

program
    : stmt_list
        { root = $1; }
    ;

stmt_list
    : %empty
        { $$ = NULL; }
    | stmt_list stmt
        { $$ = append_node($1, $2); }
    ;

stmt
    : LET IDENT '=' expr ';'
        { $$ = make_let($2, $4); }
    | LET IDENT ';'
        { $$ = make_let($2, NULL); }
    | func_decl
    | IF '(' expr ')' stmt %prec LOWER_THAN_ELSE
        { $$ = make_if($3, $5, NULL); }
    | IF '(' expr ')' stmt ELSE stmt
        { $$ = make_if($3, $5, $7); }
    | FOR '(' for_init ';' opt_expr ';' opt_expr ')' stmt
        { $$ = make_for($3, $5, $7, $9); }
    | RETURN expr ';'
        { $$ = make_return($2); }
    | '{' stmt_list '}'
        { $$ = $2; }
    | expr ';'
        { $$ = $1; }
    | ';'
        { $$ = NULL; }
    ;

func_decl
    : FUNCTION IDENT '(' IDENT ',' IDENT ')' '{' stmt_list '}'
        { $$ = make_func($2, $4, $6, $9); }
    | FUNCTION IDENT '(' IDENT ')' '{' stmt_list '}'
        { $$ = make_func($2, $4, "", $7); }
    | FUNCTION IDENT '(' ')' '{' stmt_list '}'
        { $$ = make_func($2, "", "", $6); }
    ;

for_init
    : %empty
        { $$ = NULL; }
    | LET IDENT '=' expr
        { $$ = make_let($2, $4); }
    | expr
        { $$ = $1; }
    ;

opt_expr
    : %empty
        { $$ = NULL; }
    | expr
        { $$ = $1; }
    ;

expr
    : NUMBER
        { $$ = make_num((int)$1); }
    | IDENT
        { $$ = make_var($1); }
    | '(' expr ')'
        { $$ = $2; }
    | IDENT '(' expr ',' expr ')'
        { $$ = make_call2($1, $3, $5); }
    | IDENT '(' expr ')'
        { $$ = make_call1($1, $3); }
    | IDENT '(' ')'
        { $$ = make_call0($1); }
    | expr '+' expr
        { $$ = make_binop('+', $1, $3); }
    | expr '-' expr
        { $$ = make_binop('-', $1, $3); }
    | expr '*' expr
        { $$ = make_binop('*', $1, $3); }
    | expr '/' expr
        { $$ = make_binop('/', $1, $3); }
    | expr '%' expr
        { $$ = make_binop('%', $1, $3); }
    | expr EQ_EQ expr
        { $$ = make_binop(EQ_EQ, $1, $3); }
    | expr EQ_EQ_EQ expr
        { $$ = make_binop(EQ_EQ, $1, $3); }
    | expr NOT_EQ expr
        { $$ = make_binop(NOT_EQ, $1, $3); }
    | expr NOT_EQ_EQ expr
        { $$ = make_binop(NOT_EQ, $1, $3); }
    | expr '<' expr
        { $$ = make_binop('<', $1, $3); }
    | expr '>' expr
        { $$ = make_binop('>', $1, $3); }
    | expr LESS_EQ expr
        { $$ = make_binop(LESS_EQ, $1, $3); }
    | expr GREATER_EQ expr
        { $$ = make_binop(GREATER_EQ, $1, $3); }
    | expr AND expr
        { $$ = make_binop(AND, $1, $3); }
    | expr OR expr
        { $$ = make_binop(OR, $1, $3); }
    | '-' expr %prec UMINUS
        { $$ = make_unop('-', $2); }
    | '!' expr
        { $$ = make_unop('!', $2); }
    | IDENT INC
        { $$ = make_inc(0, $1); }
    | IDENT DEC
        { $$ = make_dec(0, $1); }
    | INC IDENT %prec UMINUS
        { $$ = make_inc(1, $2); }
    | DEC IDENT %prec UMINUS
        { $$ = make_dec(1, $2); }
    | IDENT '=' expr
        { $$ = make_assign('=', $1, $3); }
    | IDENT PLUS_ASSIGN expr
        { $$ = make_assign(PLUS_ASSIGN, $1, $3); }
    | IDENT MINUS_ASSIGN expr
        { $$ = make_assign(MINUS_ASSIGN, $1, $3); }
    | IDENT STAR_ASSIGN expr
        { $$ = make_assign(STAR_ASSIGN, $1, $3); }
    | IDENT SLASH_ASSIGN expr
        { $$ = make_assign(SLASH_ASSIGN, $1, $3); }
    ;

%%

void yyerror(const char *msg) {
    fprintf(stderr, "Syntax error at line %d: %s\n", yylloc.first_line, msg);
}

typedef struct Func {
    char name[32];
    char p1[32];
    char p2[32];
    Node *body;
} Func;

static Func funcs[32];
static int func_count = 0;

static void define_func(char *name, char *p1, char *p2, Node *body) {
    for (int i = 0; i < func_count; i++) {
        if (strcmp(funcs[i].name, name) == 0) {
            funcs[i].body = body;
            return;
        }
    }
    if (func_count < 32) {
        strncpy(funcs[func_count].name, name, 31);
        strncpy(funcs[func_count].p1, p1, 31);
        strncpy(funcs[func_count].p2, p2, 31);
        funcs[func_count].body = body;
        func_count++;
    }
}

static Func *find_func(char *name) {
    for (int i = 0; i < func_count; i++) {
        if (strcmp(funcs[i].name, name) == 0) return &funcs[i];
    }
    return NULL;
}

typedef struct Frame {
    char names[16][32];
    int vals[16];
    int count;
} Frame;

static Frame call_stack[64];
static int stack_top = 0;
static FILE *out_file = NULL;

static int get_var(const char *name) {
    for (int i = 0; i < call_stack[stack_top].count; i++) {
        if (strcmp(call_stack[stack_top].names[i], name) == 0)
            return call_stack[stack_top].vals[i];
    }
    if (stack_top > 0) {
        for (int i = 0; i < call_stack[0].count; i++) {
            if (strcmp(call_stack[0].names[i], name) == 0)
                return call_stack[0].vals[i];
        }
    }
    return 0;
}

static void set_var(const char *name, int val) {
    for (int i = 0; i < call_stack[stack_top].count; i++) {
        if (strcmp(call_stack[stack_top].names[i], name) == 0) {
            call_stack[stack_top].vals[i] = val;
            return;
        }
    }
    if (stack_top > 0) {
        for (int i = 0; i < call_stack[0].count; i++) {
            if (strcmp(call_stack[0].names[i], name) == 0) {
                call_stack[0].vals[i] = val;
                return;
            }
        }
    }
    int idx = call_stack[stack_top].count;
    if (idx < 16) {
        strncpy(call_stack[stack_top].names[idx], name, 31);
        call_stack[stack_top].vals[idx] = val;
        call_stack[stack_top].count++;
    }
}

static void decl_var(const char *name, int val) {
    for (int i = 0; i < call_stack[stack_top].count; i++) {
        if (strcmp(call_stack[stack_top].names[i], name) == 0) {
            call_stack[stack_top].vals[i] = val;
            return;
        }
    }
    int idx = call_stack[stack_top].count;
    if (idx < 16) {
        strncpy(call_stack[stack_top].names[idx], name, 31);
        call_stack[stack_top].vals[idx] = val;
        call_stack[stack_top].count++;
    }
}

typedef struct ExecResult {
    int is_return;
    int val;
} ExecResult;

static int eval_expr(Node *n);
static ExecResult exec_stmt(Node *n);

static int eval_expr(Node *n) {
    if (!n) return 0;
    if (n->kind == KIND_NUM) return n->val;
    if (n->kind == KIND_VAR) return get_var(n->name);

    if (n->kind == KIND_UNOP) {
        int v = eval_expr(n->left);
        if (n->op == '-') return -v;
        if (n->op == '!') return !v;
        return v;
    }

    if (n->kind == KIND_BINOP) {
        if (n->op == AND) {
            int l = eval_expr(n->left);
            if (!l) return 0;
            return eval_expr(n->right) ? 1 : 0;
        }
        if (n->op == OR) {
            int l = eval_expr(n->left);
            if (l) return 1;
            return eval_expr(n->right) ? 1 : 0;
        }

        int l = eval_expr(n->left);
        int r = eval_expr(n->right);

        switch (n->op) {
            case '+': return l + r;
            case '-': return l - r;
            case '*': return l * r;
            case '/': return r != 0 ? l / r : 0;
            case '%': return r != 0 ? l % r : 0;
            case '<': return l < r;
            case '>': return l > r;
            case LESS_EQ: return l <= r;
            case GREATER_EQ: return l >= r;
            case EQ_EQ:
            case EQ_EQ_EQ: return l == r;
            case NOT_EQ:
            case NOT_EQ_EQ: return l != r;
        }
    }

    if (n->kind == KIND_ASSIGN) {
        int r = eval_expr(n->left);
        int val = r;
        if (n->op == PLUS_ASSIGN)  val = get_var(n->name) + r;
        if (n->op == MINUS_ASSIGN) val = get_var(n->name) - r;
        if (n->op == STAR_ASSIGN)  val = get_var(n->name) * r;
        if (n->op == SLASH_ASSIGN) val = r != 0 ? get_var(n->name) / r : 0;
        set_var(n->name, val);
        return val;
    }

    if (n->kind == KIND_INC) {
        int cur = get_var(n->name);
        set_var(n->name, cur + 1);
        return n->val ? (cur + 1) : cur;
    }

    if (n->kind == KIND_DEC) {
        int cur = get_var(n->name);
        set_var(n->name, cur - 1);
        return n->val ? (cur - 1) : cur;
    }

    if (n->kind == KIND_CALL) {
        if (strcmp(n->name, "print") == 0) {
            int v = eval_expr(n->left);
            printf("%d\n", v);
            if (out_file) fprintf(out_file, "%d\n", v);
            return v;
        }

        Func *f = find_func(n->name);
        if (!f) return 0;

        int a1 = n->left ? eval_expr(n->left) : 0;
        int a2 = n->right ? eval_expr(n->right) : 0;

        stack_top++;
        call_stack[stack_top].count = 0;

        if (f->p1[0]) decl_var(f->p1, a1);
        if (f->p2[0]) decl_var(f->p2, a2);

        ExecResult res = exec_stmt(f->body);

        stack_top--;
        return res.val;
    }

    return 0;
}

static ExecResult exec_stmt(Node *n) {
    ExecResult res = {0, 0};
    while (n) {
        if (n->kind == KIND_LET) {
            int v = n->left ? eval_expr(n->left) : 0;
            decl_var(n->name, v);
        }
        else if (n->kind == KIND_FUNC) {
            define_func(n->name, n->p1, n->p2, n->body);
        }
        else if (n->kind == KIND_RETURN) {
            res.is_return = 1;
            res.val = n->left ? eval_expr(n->left) : 0;
            return res;
        }
        else if (n->kind == KIND_IF) {
            if (eval_expr(n->cond)) {
                res = exec_stmt(n->body);
                if (res.is_return) return res;
            } else if (n->right) {
                res = exec_stmt(n->right);
                if (res.is_return) return res;
            }
        }
        else if (n->kind == KIND_FOR) {
            if (n->left) exec_stmt(n->left);
            while (n->cond == NULL || eval_expr(n->cond)) {
                res = exec_stmt(n->body);
                if (res.is_return) return res;
                if (n->step) eval_expr(n->step);
            }
        }
        else {
            eval_expr(n);
        }
        n = n->next;
    }
    return res;
}

int main(int argc, char **argv) {
    const char *filename = (argc > 1) ? argv[1] : "input.txt";
    yyin = fopen(filename, "r");
    if (!yyin) {
        perror(filename);
        return 1;
    }

    out_file = fopen("output.txt", "w");

    yyparse();
    fclose(yyin);

    stack_top = 0;
    call_stack[0].count = 0;
    exec_stmt(root);

    if (out_file) fclose(out_file);
    return 0;
}
