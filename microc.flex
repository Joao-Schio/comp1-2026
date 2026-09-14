/*
 * microc.flex
 *
 * Analisador lexico (scanner) para a linguagem Micro C.
 * Disciplina: Compiladores I - FACOM
 *
 * Implementacao do Trabalho Pratico 1 a partir do esqueleto fornecido.
 *
 * Compilacao:
 *      flex microc.flex
 *      gcc lex.yy.c -o lexer
 *
 * Uso:
 *      ./lexer test.mc
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------------------------------------------------------------------
 * 1. VOCABULARIO DE TOKENS (equivalente a tokens.h)
 * ------------------------------------------------------------------- */

typedef enum {
    /* Tokens fundamentais */
    UNDEF,          /* token indefinido (usado para reportar erros) */
    ID,             /* identificador                                */
    END_OF_FILE,    /* fim de arquivo                                */

    /* Constantes literais */
    INTEGERCONST,
    CHARCONST,
    STRINGCONST,

    /* Operadores aritmeticos */
    PLUS, MINUS, MUL, DIV, MOD,

    /* Operadores relacionais e logicos */
    EQ, NEQ, LT, GT, LEQ, GEQ, AND, OR, NOT,

    /* Simbolos de atribuicao e pontuacao */
    ASSIGN, SEMICOLON, COMMA, LPAREN, RPAREN,
    LBRACE, RBRACE, LBRACKET, RBRACKET,

    /* Palavras reservadas */
    MAIN, IF, ELSE, FOR, RETURN, INT, CHAR, PRINT
} TokenType;

/* Nomes dos tokens, usados apenas pelo main() de teste abaixo para
 * imprimir o tipo de cada token de forma legivel. Mantenha esta lista
 * na MESMA ORDEM do enum TokenType. */
static const char *nome_token[] = {
    "UNDEF", "ID", "END_OF_FILE",
    "INTEGERCONST", "CHARCONST", "STRINGCONST",
    "PLUS", "MINUS", "MUL", "DIV", "MOD",
    "EQ", "NEQ", "LT", "GT", "LEQ", "GEQ", "AND", "OR", "NOT",
    "ASSIGN", "SEMICOLON", "COMMA", "LPAREN", "RPAREN",
    "LBRACE", "RBRACE", "LBRACKET", "RBRACKET",
    "MAIN", "IF", "ELSE", "FOR", "RETURN", "INT", "CHAR", "PRINT"
};

/* Valor semantico do token corrente. */
typedef struct {
    char *symbol;      /* lexema para ID, INTEGERCONST, CHARCONST, STRINGCONST */
    char *error_msg;   /* mensagem de erro, usada apenas quando tipo == UNDEF   */
} YYSTYPE;

YYSTYPE microc_yylval;

/* Linha atual do arquivo-fonte sendo processado. Deve ser incrementada
 * toda vez que uma quebra de linha for consumida pelo scanner (seja em
 * codigo "normal", dentro de comentarios ou dentro de strings). */
int linha_atual = 1;

/* Funcao auxiliar para preencher microc_yylval.symbol com uma copia do
 * texto reconhecido (yytext). */
static void guarda_lexema(void) {
    microc_yylval.symbol = strdup(yytext);
}

/* Converte as sequencias de escape exigidas para constantes de caractere
 * e string. O texto recebido inclui as aspas delimitadoras. */
static char *converte_literal(const char *texto, size_t tamanho) {
    char *saida = malloc(tamanho + 1);
    size_t i;
    size_t j = 0;

    if (!saida) {
        fprintf(stderr, "Erro: memoria insuficiente\n");
        exit(EXIT_FAILURE);
    }

    for (i = 1; i + 1 < tamanho; i++) {
        if (texto[i] == '\\' && i + 1 < tamanho - 1) {
            char proximo = texto[++i];

            switch (proximo) {
                case 'n':  saida[j++] = '\n'; break;
                case 't':  saida[j++] = '\t'; break;
                case '\\': saida[j++] = '\\'; break;
                case '"':  saida[j++] = '"';  break;
                case '\'': saida[j++] = '\''; break;
                case '0':  saida[j++] = '\0'; break;
                default:
                    /* Escape nao listado: preserva exatamente o texto lido. */
                    saida[j++] = '\\';
                    saida[j++] = proximo;
                    break;
            }
        } else {
            saida[j++] = texto[i];
        }
    }

    saida[j] = '\0';
    return saida;
}

/* Numero de caracteres logicos dentro da constante de caractere atual. */
static int caracteres_char = 0;

%}

/* -----------------------------------------------------------------------
 * 2. SECAO DE DEFINICOES
 * ------------------------------------------------------------------- */

DIGIT       [0-9]
LETRA       [a-zA-Z_]
ALFANUM     [a-zA-Z0-9_]

%x COMMENT STRING CHARLIT NEGATIVE

%%

 /* -----------------------------------------------------------------------
  * 3. SECAO DE REGRAS
  * --------------------------------------------------------------------- */

 /* --- Fim de arquivo -----------------------------------------------------
  * Tratada explicitamente (em vez de depender do retorno automatico 0
  * do flex), pois o token UNDEF tambem vale 0 no enum TokenType -- se
  * dependessemos do comportamento padrao, um erro lexico seria
  * confundido com o fim do arquivo pelo main() de teste abaixo. */
<<EOF>>             { return END_OF_FILE; }

 /* --- Espacos em branco e quebras de linha ---------------------------- */
\n                  { linha_atual++; }
[ \t\r]+            { /* ignora espacos em branco */ }

 /* --- Comentarios ------------------------------------------------------
  * Estados exclusivos permitem consumir todo o comentario sem produzir
  * tokens, mantendo a contagem correta de linhas. */
"//".*              { /* comentario de linha: ignora ate o fim da linha */ }

"/*"                { BEGIN(COMMENT); }
<COMMENT>"*/"       { BEGIN(INITIAL); }
<COMMENT>\n         { linha_atual++; }
<COMMENT><<EOF>>    {
                        microc_yylval.error_msg = "EOF em comentario";
                        BEGIN(INITIAL);
                        return UNDEF;
                    }
<COMMENT>.          { /* consome qualquer outro caractere dentro do comentario */ }

 /* Fechamento de comentario sem abertura correspondente. */
"*/"                {
                        microc_yylval.error_msg = "Comentario nao iniciado";
                        return UNDEF;
                    }

 /* --- Palavras reservadas e identificadores ---------------------------- */
{LETRA}{ALFANUM}*   {
                        if (strcmp(yytext, "main") == 0)   return MAIN;
                        if (strcmp(yytext, "if") == 0)     return IF;
                        if (strcmp(yytext, "else") == 0)   return ELSE;
                        if (strcmp(yytext, "for") == 0)    return FOR;
                        if (strcmp(yytext, "return") == 0) return RETURN;
                        if (strcmp(yytext, "int") == 0)    return INT;
                        if (strcmp(yytext, "char") == 0)   return CHAR;
                        if (strcmp(yytext, "print") == 0)  return PRINT;

                        guarda_lexema();
                        return ID;
                    }

 /* --- Constantes inteiras -----------------------------------------------*/
{DIGIT}+            {
                        guarda_lexema();
                        return INTEGERCONST;
                    }
<NEGATIVE>{DIGIT}+  {
                        BEGIN(INITIAL);
                        guarda_lexema();
                        return INTEGERCONST;
                    }

 /* --- Constantes de caractere --------------------------------------------*/
\'                  {
                        caracteres_char = 0;
                        BEGIN(CHARLIT);
                        yymore();
                    }

<CHARLIT>\\[nt\\\'"0] {
                        caracteres_char++;
                        yymore();
                    }

<CHARLIT>\\.        {
                        yymore();
                    }

<CHARLIT>[^\\\'\n]  {
                        caracteres_char++;
                        yymore();
                    }

<CHARLIT>\'          {
                        BEGIN(INITIAL);

                        if (caracteres_char != 1) {
                            microc_yylval.error_msg = "Constante de caractere invalida";
                            return UNDEF;
                        }

                        microc_yylval.symbol = converte_literal(yytext, (size_t)yyleng);
                        return CHARCONST;
                    }

<CHARLIT>\\\n        {
                        linha_atual++;
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "Constante de caractere nao terminada";
                        return UNDEF;
                    }

<CHARLIT>\n          {
                        linha_atual++;
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "Constante de caractere nao terminada";
                        return UNDEF;
                    }

<CHARLIT><<EOF>>     {
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "EOF em constante de caractere";
                        return UNDEF;
                    }

 /* --- Constantes de string -----------------------------------------------*/
   
\"                  {
                        BEGIN(STRING);
                        yymore();
                    }

<STRING>\\[nt\\"0]  { yymore(); }

<STRING>\\.         {
                        yymore();
                    }

<STRING>[^\\"\n\x00]+ { yymore(); }

<STRING>\x00         {
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "String contem caractere nulo";
                        return UNDEF;
                    }

<STRING>\"           {
                        BEGIN(INITIAL);
                        microc_yylval.symbol = converte_literal(yytext, (size_t)yyleng);
                        return STRINGCONST;
                    }

<STRING>\\\n         {
                        linha_atual++;
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "String nao terminada";
                        return UNDEF;
                    }

<STRING>\n           {
                        linha_atual++;
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "String nao terminada";
                        return UNDEF;
                    }

<STRING><<EOF>>      {
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "EOF em string";
                        return UNDEF;
                    }

 /* --- Operadores relacionais e logicos ---------------------------------
"=="                { return EQ; }
"="                 { return ASSIGN; }
"!="                { return NEQ; }
"!"                 { return NOT; }
"<="                { return LEQ; }
"<"                 { return LT; }
">="                { return GEQ; }
">"                 { return GT; }
"&&"                { return AND; }
"||"                { return OR; }

 /* --- Operadores aritmeticos e simbolos de pontuacao ------------------ */
"+"                 { return PLUS; }
"-"                 {
                        int proximo = input();

                        if (proximo >= '0' && proximo <= '9') {
                            /* Devolve o digito ao fluxo e continua o mesmo
                             * lexema no estado NEGATIVE. */
                            unput(proximo);
                            yymore();
                            BEGIN(NEGATIVE);
                        } else {
                            if (proximo != EOF) {
                                unput(proximo);
                            }
                            return MINUS;
                        }
                    }
"*"                 { return MUL; }
"/"                 { return DIV; }
"%"                 { return MOD; }
";"                 { return SEMICOLON; }
","                 { return COMMA; }
"("                 { return LPAREN; }
")"                 { return RPAREN; }
"{"                 { return LBRACE; }
"}"                 { return RBRACE; }
"["                 { return LBRACKET; }
"]"                 { return RBRACKET; }

 /* --- Caractere invalido -------------------------------------------------
  * Casa com qualquer caractere que nao tenha correspondido a nenhuma
  * regra anterior. Deve ser SEMPRE a ultima regra do arquivo. */
.                   {
                        microc_yylval.error_msg = strdup(yytext);
                        return UNDEF;
                    }

%%

/* -----------------------------------------------------------------------
 * 4. SUB-ROTINAS DO USUARIO
 * ------------------------------------------------------------------- */

/* yywrap: informa ao flex que, ao atingir o EOF, a leitura deve
 * simplesmente parar (nao ha um proximo arquivo a processar). */
int yywrap(void) {
    return 1;
}

/* main() de teste: le o arquivo passado como argumento e imprime, para
 * cada token reconhecido, seu tipo, lexema e linha -- no mesmo espirito
 * do utilitario "lexer" mencionado no enunciado. */
int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo.mc>\n", argv[0]);
        return 1;
    }

    FILE *arquivo_fonte = fopen(argv[1], "r");
    if (!arquivo_fonte) {
        fprintf(stderr, "Erro: nao foi possivel abrir o arquivo '%s'\n", argv[1]);
        return 1;
    }
    yyin = arquivo_fonte;

    int tipo;
    while ((tipo = yylex()) != END_OF_FILE) {
        if (tipo == UNDEF) {
            fprintf(stderr, "ERRO LEXICO (linha %d): %s\n",
                    linha_atual, microc_yylval.error_msg);
            continue;
        }
        printf("Token: tipo = %-13s lexema = '%s'  linha = %d\n",
               nome_token[tipo], yytext, linha_atual);
    }

    fclose(arquivo_fonte);
    return 0;
}
