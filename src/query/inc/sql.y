//lemon parser file to generate sql parse by using finite-state-machine code used to parse sql
//usage: lemon sql.y
%token_prefix TK_

%token_type {SStrToken}
%default_type {SStrToken}
%extra_argument {SSqlInfo* pInfo}

%fallback ID BOOL TINYINT SMALLINT INTEGER BIGINT FLOAT DOUBLE STRING TIMESTAMP BINARY NCHAR.

%left OR.
%left AND.
%right NOT.
%left EQ NE ISNULL NOTNULL IS LIKE MATCH NMATCH GLOB BETWEEN IN.
%left GT GE LT LE.
%left BITAND BITOR LSHIFT RSHIFT.
%left PLUS MINUS.
%left DIVIDE TIMES.
%left STAR SLASH REM.
%left CONCAT.
%right UMINUS UPLUS BITNOT.

%include {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include "qSqlparser.h"
#include "tcmdtype.h"
#include "ttoken.h"
#include "ttokendef.h"
#include "tutil.h"
#include "tvariant.h"
}

%syntax_error {
  pInfo->valid = false;
  int32_t outputBufLen = tListLen(pInfo->msg);
  int32_t len = 0;

  if(TOKEN.z) {
    char msg[] = "syntax error near \"%s\"";
    int32_t sqlLen = strlen(&TOKEN.z[0]);

    if (sqlLen + sizeof(msg)/sizeof(msg[0]) + 1 > outputBufLen) {
        char tmpstr[128] = {0};
        memcpy(tmpstr, &TOKEN.z[0], sizeof(tmpstr)/sizeof(tmpstr[0]) - 1);
        len = sprintf(pInfo->msg, msg, tmpstr);
    } else {
        len = sprintf(pInfo->msg, msg, &TOKEN.z[0]);
    }

  } else {
    len = sprintf(pInfo->msg, "Incomplete SQL statement");
  }

  assert(len <= outputBufLen);
}

%parse_accept       {}

program ::= cmd.    {}

//////////////////////////////////THE SHOW STATEMENT///////////////////////////////////////////
cmd ::= SHOW DATABASES.  { setShowOptions(pInfo, TSDB_MGMT_TABLE_DB, 0, 0);}
cmd ::= SHOW TOPICS.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_TP, 0, 0);}
cmd ::= SHOW FUNCTIONS.  { setShowOptions(pInfo, TSDB_MGMT_TABLE_FUNCTION, 0, 0);}
cmd ::= SHOW MNODES.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_MNODE, 0, 0);}
cmd ::= SHOW DNODES.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_DNODE, 0, 0);}
cmd ::= SHOW ACCOUNTS.   { setShowOptions(pInfo, TSDB_MGMT_TABLE_ACCT, 0, 0);}
cmd ::= SHOW USERS.      { setShowOptions(pInfo, TSDB_MGMT_TABLE_USER, 0, 0);}

cmd ::= SHOW MODULES.    { setShowOptions(pInfo, TSDB_MGMT_TABLE_MODULE, 0, 0);  }
cmd ::= SHOW QUERIES.    { setShowOptions(pInfo, TSDB_MGMT_TABLE_QUERIES, 0, 0);  }
cmd ::= SHOW CONNECTIONS.{ setShowOptions(pInfo, TSDB_MGMT_TABLE_CONNS, 0, 0);}
cmd ::= SHOW STREAMS.    { setShowOptions(pInfo, TSDB_MGMT_TABLE_STREAMS, 0, 0);  }
cmd ::= SHOW VARIABLES.  { setShowOptions(pInfo, TSDB_MGMT_TABLE_VARIABLES, 0, 0);  }
cmd ::= SHOW SCORES.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_SCORES, 0, 0);   }
cmd ::= SHOW GRANTS.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_GRANTS, 0, 0);   }

cmd ::= SHOW VNODES.                { setShowOptions(pInfo, TSDB_MGMT_TABLE_VNODES, 0, 0); }
cmd ::= SHOW VNODES ids(X).     { setShowOptions(pInfo, TSDB_MGMT_TABLE_VNODES, &X, 0); }


%type dbPrefix {SStrToken}
dbPrefix(A) ::=.                   {A.n = 0; A.type = 0;}
dbPrefix(A) ::= ids(X) DOT.        {A = X;  }

%type cpxName {SStrToken}
cpxName(A) ::= .             {A.n = 0;  }
cpxName(A) ::= DOT ids(Y).   {A = Y; A.n += 1;    }
cmd ::= SHOW CREATE TABLE ids(X) cpxName(Y).    {
   X.n += Y.n;
   setDCLSqlElems(pInfo, TSDB_SQL_SHOW_CREATE_TABLE, 1, &X);
}
cmd ::= SHOW CREATE STABLE ids(X) cpxName(Y).    {
   X.n += Y.n;
   setDCLSqlElems(pInfo, TSDB_SQL_SHOW_CREATE_STABLE, 1, &X);
}

cmd ::= SHOW CREATE DATABASE ids(X). {
  setDCLSqlElems(pInfo, TSDB_SQL_SHOW_CREATE_DATABASE, 1, &X);
}

cmd ::= SHOW dbPrefix(X) TABLES.         {
    setShowOptions(pInfo, TSDB_MGMT_TABLE_TABLE, &X, 0);
}

cmd ::= SHOW dbPrefix(X) TABLES LIKE ids(Y).         {
    setShowOptions(pInfo, TSDB_MGMT_TABLE_TABLE, &X, &Y);
}

cmd ::= SHOW dbPrefix(X) STABLES.      {
    setShowOptions(pInfo, TSDB_MGMT_TABLE_METRIC, &X, 0);
}

cmd ::= SHOW dbPrefix(X) STABLES LIKE ids(Y).      {
    SStrToken token;
    tSetDbName(&token, &X);
    setShowOptions(pInfo, TSDB_MGMT_TABLE_METRIC, &token, &Y);
}

cmd ::= SHOW dbPrefix(X) VGROUPS.    {
    SStrToken token;
    tSetDbName(&token, &X);
    setShowOptions(pInfo, TSDB_MGMT_TABLE_VGROUP, &token, 0);
}

//drop configure for tables
cmd ::= DROP TABLE ifexists(Y) ids(X) cpxName(Z).   {
    X.n += Z.n;
    setDropDbTableInfo(pInfo, TSDB_SQL_DROP_TABLE, &X, &Y, -1, -1);
}

//drop stable
cmd ::= DROP STABLE ifexists(Y) ids(X) cpxName(Z).   {
    X.n += Z.n;
    setDropDbTableInfo(pInfo, TSDB_SQL_DROP_TABLE, &X, &Y, -1, TSDB_SUPER_TABLE);
}

cmd ::= DROP DATABASE ifexists(Y) ids(X).    { setDropDbTableInfo(pInfo, TSDB_SQL_DROP_DB, &X, &Y, TSDB_DB_TYPE_DEFAULT, -1); }
cmd ::= DROP TOPIC ifexists(Y) ids(X).    { setDropDbTableInfo(pInfo, TSDB_SQL_DROP_DB, &X, &Y, TSDB_DB_TYPE_TOPIC, -1); }
cmd ::= DROP FUNCTION ids(X).    { setDropFuncInfo(pInfo, TSDB_SQL_DROP_FUNCTION, &X); }

cmd ::= DROP DNODE ids(X).       { setDCLSqlElems(pInfo, TSDB_SQL_DROP_DNODE, 1, &X);    }
cmd ::= DROP USER ids(X).        { setDCLSqlElems(pInfo, TSDB_SQL_DROP_USER, 1, &X);     }
cmd ::= DROP ACCOUNT ids(X).     { setDCLSqlElems(pInfo, TSDB_SQL_DROP_ACCT, 1, &X);  }

/////////////////////////////////THE USE STATEMENT//////////////////////////////////////////
cmd ::= USE ids(X).              { setDCLSqlElems(pInfo, TSDB_SQL_USE_DB, 1, &X);}

/////////////////////////////////THE DESCRIBE STATEMENT/////////////////////////////////////
cmd ::= DESCRIBE ids(X) cpxName(Y). {
    X.n += Y.n;
    setDCLSqlElems(pInfo, TSDB_SQL_DESCRIBE_TABLE, 1, &X);
}

cmd ::= DESC ids(X) cpxName(Y). {
    X.n += Y.n;
    setDCLSqlElems(pInfo, TSDB_SQL_DESCRIBE_TABLE, 1, &X);
}
/////////////////////////////////THE ALTER STATEMENT////////////////////////////////////////
cmd ::= ALTER USER ids(X) PASS ids(Y).          { setAlterUserSql(pInfo, TSDB_ALTER_USER_PASSWD, &X, &Y, NULL);    }
cmd ::= ALTER USER ids(X) PRIVILEGE ids(Y).     { setAlterUserSql(pInfo, TSDB_ALTER_USER_PRIVILEGES, &X, NULL, &Y);}
cmd ::= ALTER DNODE ids(X) ids(Y).              { setDCLSqlElems(pInfo, TSDB_SQL_CFG_DNODE, 2, &X, &Y);          }
cmd ::= ALTER DNODE ids(X) ids(Y) ids(Z).       { setDCLSqlElems(pInfo, TSDB_SQL_CFG_DNODE, 3, &X, &Y, &Z);      }
cmd ::= ALTER LOCAL ids(X).                     { setDCLSqlElems(pInfo, TSDB_SQL_CFG_LOCAL, 1, &X);              }
cmd ::= ALTER LOCAL ids(X) ids(Y).              { setDCLSqlElems(pInfo, TSDB_SQL_CFG_LOCAL, 2, &X, &Y);          }
cmd ::= ALTER DATABASE ids(X) alter_db_optr(Y). { SStrToken t = {0};  setCreateDbInfo(pInfo, TSDB_SQL_ALTER_DB, &X, &Y, &t);}
cmd ::= ALTER TOPIC ids(X) alter_topic_optr(Y). { SStrToken t = {0};  setCreateDbInfo(pInfo, TSDB_SQL_ALTER_DB, &X, &Y, &t);}

cmd ::= ALTER ACCOUNT ids(X) acct_optr(Z).      { setCreateAcctSql(pInfo, TSDB_SQL_ALTER_ACCT, &X, NULL, &Z);}
cmd ::= ALTER ACCOUNT ids(X) PASS ids(Y) acct_optr(Z).      { setCreateAcctSql(pInfo, TSDB_SQL_ALTER_ACCT, &X, &Y, &Z);}

////////////////////////////// COMPACT STATEMENT //////////////////////////////////////////////

cmd ::= COMPACT VNODES IN LP exprlist(Y) RP.    { setCompactVnodeSql(pInfo, TSDB_SQL_COMPACT_VNODE, Y);}

// An IDENTIFIER can be a generic identifier, or one of several keywords.
// Any non-standard keyword can also be an identifier.
// And "ids" is an identifer-or-string.
%type ids {SStrToken}
ids(A) ::= ID(X).        {A = X; }
ids(A) ::= STRING(X).    {A = X; }

%type ifexists {SStrToken}
ifexists(X) ::= IF EXISTS.          { X.n = 1;}
ifexists(X) ::= .                   { X.n = 0;}

%type ifnotexists {SStrToken}
ifnotexists(X) ::= IF NOT EXISTS.   { X.n = 1;}
ifnotexists(X) ::= .                { X.n = 0;}

/////////////////////////////////THE CREATE STATEMENT///////////////////////////////////////
//create option for dnode/db/user/account
cmd ::= CREATE DNODE   ids(X).     { setDCLSqlElems(pInfo, TSDB_SQL_CREATE_DNODE, 1, &X);}
cmd ::= CREATE ACCOUNT ids(X) PASS ids(Y) acct_optr(Z).
                                { setCreateAcctSql(pInfo, TSDB_SQL_CREATE_ACCT, &X, &Y, &Z);}
cmd ::= CREATE DATABASE ifnotexists(Z) ids(X) db_optr(Y).  { setCreateDbInfo(pInfo, TSDB_SQL_CREATE_DB, &X, &Y, &Z);}
cmd ::= CREATE TOPIC ifnotexists(Z) ids(X) topic_optr(Y).  { setCreateDbInfo(pInfo, TSDB_SQL_CREATE_DB, &X, &Y, &Z);}
cmd ::= CREATE FUNCTION ids(X) AS ids(Y) OUTPUTTYPE typename(Z) bufsize(B).   { setCreateFuncInfo(pInfo, TSDB_SQL_CREATE_FUNCTION, &X, &Y, &Z, &B, 1);}
cmd ::= CREATE AGGREGATE FUNCTION ids(X) AS ids(Y) OUTPUTTYPE typename(Z) bufsize(B).   { setCreateFuncInfo(pInfo, TSDB_SQL_CREATE_FUNCTION, &X, &Y, &Z, &B, 2);}
cmd ::= CREATE USER ids(X) PASS ids(Y).     { setCreateUserSql(pInfo, &X, &Y);}

bufsize(Y) ::= .                                { Y.n = 0;   }
bufsize(Y) ::= BUFSIZE INTEGER(X).              { Y = X;     }

pps(Y) ::= .                                { Y.n = 0;   }
pps(Y) ::= PPS INTEGER(X).                  { Y = X;     }

tseries(Y) ::= .                            { Y.n = 0;   }
tseries(Y) ::= TSERIES INTEGER(X).          { Y = X;     }

dbs(Y) ::= .                                { Y.n = 0;   }
dbs(Y) ::= DBS INTEGER(X).                  { Y = X;     }

streams(Y) ::= .                            { Y.n = 0;   }
streams(Y) ::= STREAMS INTEGER(X).          { Y = X;     }

storage(Y) ::= .                            { Y.n = 0;   }
storage(Y) ::= STORAGE INTEGER(X).          { Y = X;     }

qtime(Y) ::= .                              { Y.n = 0;   }
qtime(Y) ::= QTIME INTEGER(X).              { Y = X;     }

users(Y) ::= .                              { Y.n = 0;   }
users(Y) ::= USERS INTEGER(X).              { Y = X;     }

conns(Y) ::= .                              { Y.n = 0;   }
conns(Y) ::= CONNS INTEGER(X).              { Y = X;     }

state(Y) ::= .                              { Y.n = 0;   }
state(Y) ::= STATE ids(X).                  { Y = X;     }

%type acct_optr {SCreateAcctInfo}
acct_optr(Y) ::= pps(C) tseries(D) storage(P) streams(F) qtime(Q) dbs(E) users(K) conns(L) state(M). {
    Y.maxUsers   = (K.n>0)?atoi(K.z):-1;
    Y.maxDbs     = (E.n>0)?atoi(E.z):-1;
    Y.maxTimeSeries = (D.n>0)?atoi(D.z):-1;
    Y.maxStreams = (F.n>0)?atoi(F.z):-1;
    Y.maxPointsPerSecond     = (C.n>0)?atoi(C.z):-1;
    Y.maxStorage = (P.n>0)?strtoll(P.z, NULL, 10):-1;
    Y.maxQueryTime   = (Q.n>0)?strtoll(Q.z, NULL, 10):-1;
    Y.maxConnections   = (L.n>0)?atoi(L.z):-1;
    Y.stat    = M;
}

%type intitemlist {SArray*}
%destructor intitemlist {taosArrayDestroy($$);}

%type intitem {tVariant}
intitemlist(A) ::= intitemlist(X) COMMA intitem(Y). { A = tVariantListAppend(X, &Y, -1);    }
intitemlist(A) ::= intitem(X).                      { A = tVariantListAppend(NULL, &X, -1); }

intitem(A) ::= INTEGER(X).      { toTSDBType(X.type); tVariantCreate(&A, &X); }

%type keep {SArray*}
%destructor keep {taosArrayDestroy($$);}
keep(Y)    ::= KEEP intitemlist(X).           { Y = X; }

cache(Y)   ::= CACHE INTEGER(X).              { Y = X; }
replica(Y) ::= REPLICA INTEGER(X).            { Y = X; }
quorum(Y)  ::= QUORUM INTEGER(X).             { Y = X; }
days(Y)    ::= DAYS INTEGER(X).               { Y = X; }
minrows(Y) ::= MINROWS INTEGER(X).            { Y = X; }
maxrows(Y) ::= MAXROWS INTEGER(X).            { Y = X; }
blocks(Y)  ::= BLOCKS INTEGER(X).             { Y = X; }
ctime(Y)   ::= CTIME INTEGER(X).              { Y = X; }
wal(Y)     ::= WAL INTEGER(X).                { Y = X; }
fsync(Y)   ::= FSYNC INTEGER(X).              { Y = X; }
comp(Y)    ::= COMP INTEGER(X).               { Y = X; }
prec(Y)    ::= PRECISION STRING(X).           { Y = X; }
update(Y)  ::= UPDATE INTEGER(X).             { Y = X; }
cachelast(Y) ::= CACHELAST INTEGER(X).        { Y = X; }
partitions(Y) ::= PARTITIONS INTEGER(X).      { Y = X; }

%type db_optr {SCreateDbInfo}
db_optr(Y) ::= . {setDefaultCreateDbOption(&Y); Y.dbType = TSDB_DB_TYPE_DEFAULT;}

db_optr(Y) ::= db_optr(Z) cache(X).          { Y = Z; Y.cacheBlockSize = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) replica(X).        { Y = Z; Y.replica = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) quorum(X).         { Y = Z; Y.quorum = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) days(X).           { Y = Z; Y.daysPerFile = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) minrows(X).        { Y = Z; Y.minRowsPerBlock = strtod(X.z, NULL); }
db_optr(Y) ::= db_optr(Z) maxrows(X).        { Y = Z; Y.maxRowsPerBlock = strtod(X.z, NULL); }
db_optr(Y) ::= db_optr(Z) blocks(X).         { Y = Z; Y.numOfBlocks = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) ctime(X).          { Y = Z; Y.commitTime = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) wal(X).            { Y = Z; Y.walLevel = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) fsync(X).          { Y = Z; Y.fsyncPeriod = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) comp(X).           { Y = Z; Y.compressionLevel = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) prec(X).           { Y = Z; Y.precision = X; }
db_optr(Y) ::= db_optr(Z) keep(X).           { Y = Z; Y.keep = X; }
db_optr(Y) ::= db_optr(Z) update(X).         { Y = Z; Y.update = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) cachelast(X).      { Y = Z; Y.cachelast = strtol(X.z, NULL, 10); }

%type topic_optr {SCreateDbInfo}

topic_optr(Y) ::= db_optr(Z).                       { Y = Z; Y.dbType = TSDB_DB_TYPE_TOPIC; }
topic_optr(Y) ::= topic_optr(Z) partitions(X).      { Y = Z; Y.partitions = strtol(X.z, NULL, 10); }

%type alter_db_optr {SCreateDbInfo}
alter_db_optr(Y) ::= . { setDefaultCreateDbOption(&Y); Y.dbType = TSDB_DB_TYPE_DEFAULT;}

alter_db_optr(Y) ::= alter_db_optr(Z) replica(X).     { Y = Z; Y.replica = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) quorum(X).      { Y = Z; Y.quorum = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) keep(X).        { Y = Z; Y.keep = X; }
alter_db_optr(Y) ::= alter_db_optr(Z) blocks(X).      { Y = Z; Y.numOfBlocks = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) comp(X).        { Y = Z; Y.compressionLevel = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) update(X).      { Y = Z; Y.update = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) cachelast(X).   { Y = Z; Y.cachelast = strtol(X.z, NULL, 10); }

// dynamically update the following two parameters are not allowed.
//alter_db_optr(Y) ::= alter_db_optr(Z) fsync(X).       { Y = Z; Y.fsyncPeriod = strtol(X.z, NULL, 10); }
//alter_db_optr(Y) ::= alter_db_optr(Z) wal(X).         { Y = Z; Y.walLevel = strtol(X.z, NULL, 10); } not support yet

%type alter_topic_optr {SCreateDbInfo}

alter_topic_optr(Y) ::= alter_db_optr(Z).                       { Y = Z; Y.dbType = TSDB_DB_TYPE_TOPIC; }
alter_topic_optr(Y) ::= alter_topic_optr(Z) partitions(X).      { Y = Z; Y.partitions = strtol(X.z, NULL, 10); }

%type typename {TAOS_FIELD}
typename(A) ::= ids(X). {
  X.type = 0;
  tSetColumnType (&A, &X);
}

//define binary type, e.g., binary(10), nchar(10)
typename(A) ::= ids(X) LP signed(Y) RP.    {
  if (Y <= 0) {
    X.type = 0;
    tSetColumnType(&A, &X);
  } else {
    X.type = -Y;  // negative value of name length
    tSetColumnType(&A, &X);
  }
}

// define the unsigned number type
typename(A) ::= ids(X) UNSIGNED(Z). {
  X.type = 0;
  X.n = ((Z.z + Z.n) - X.z);
  tSetColumnType (&A, &X);
}

%type signed {int64_t}
signed(A) ::= INTEGER(X).         { A = strtol(X.z, NULL, 10); }
signed(A) ::= PLUS INTEGER(X).    { A = strtol(X.z, NULL, 10); }
signed(A) ::= MINUS INTEGER(X).   { A = -strtol(X.z, NULL, 10);}

////////////////////////////////// The CREATE TABLE statement ///////////////////////////////
cmd ::= CREATE TABLE  create_table_args.  {}
cmd ::= CREATE TABLE  create_stable_args. {}
cmd ::= CREATE STABLE create_stable_args. {}
cmd ::= CREATE TABLE create_table_list(Z). { pInfo->type = TSDB_SQL_CREATE_TABLE; pInfo->pCreateTableInfo = Z;}

%type create_table_list{SCreateTableSql*}
%destructor create_table_list{destroyCreateTableSql($$);}
create_table_list(A) ::= create_from_stable(Z). {
  SCreateTableSql* pCreateTable = calloc(1, sizeof(SCreateTableSql));
  pCreateTable->childTableInfo = taosArrayInit(4, sizeof(SCreatedTableInfo));

  taosArrayPush(pCreateTable->childTableInfo, &Z);
  pCreateTable->type = TSQL_CREATE_TABLE_FROM_STABLE;
  A = pCreateTable;
}

create_table_list(A) ::= create_table_list(X) create_from_stable(Z). {
  taosArrayPush(X->childTableInfo, &Z);
  A = X;
}

%type create_table_args{SCreateTableSql*}
create_table_args(A) ::= ifnotexists(U) ids(V) cpxName(Z) LP columnlist(X) RP. {
  A = tSetCreateTableInfo(X, NULL, NULL, TSQL_CREATE_TABLE);
  setSqlInfo(pInfo, A, NULL, TSDB_SQL_CREATE_TABLE);

  V.n += Z.n;
  setCreatedTableName(pInfo, &V, &U);
}

// create super table
%type create_stable_args{SCreateTableSql*}
create_stable_args(A) ::= ifnotexists(U) ids(V) cpxName(Z) LP columnlist(X) RP TAGS LP columnlist(Y) RP. {
  A = tSetCreateTableInfo(X, Y, NULL, TSQL_CREATE_STABLE);
  setSqlInfo(pInfo, A, NULL, TSDB_SQL_CREATE_TABLE);

  V.n += Z.n;
  setCreatedTableName(pInfo, &V, &U);
}

// create table by using super table
// create table table_name using super_table_name tags(tag_values1, tag_values2)
%type create_from_stable{SCreatedTableInfo}
create_from_stable(A) ::= ifnotexists(U) ids(V) cpxName(Z) USING ids(X) cpxName(F) TAGS LP tagitemlist(Y) RP.  {
  X.n += F.n;
  V.n += Z.n;
  A = createNewChildTableInfo(&X, NULL, Y, &V, &U);
}

create_from_stable(A) ::= ifnotexists(U) ids(V) cpxName(Z) USING ids(X) cpxName(F) LP tagNamelist(P) RP TAGS LP tagitemlist(Y) RP.  {
  X.n += F.n;
  V.n += Z.n;
  A = createNewChildTableInfo(&X, P, Y, &V, &U);
}

%type tagNamelist{SArray*}
%destructor tagNamelist {taosArrayDestroy($$);}
tagNamelist(A) ::= tagNamelist(X) COMMA ids(Y).  {taosArrayPush(X, &Y); A = X;  }
tagNamelist(A) ::= ids(X).                      {A = taosArrayInit(4, sizeof(SStrToken)); taosArrayPush(A, &X);}

// create stream
// create table table_name as select count(*) from super_table_name interval(time)
create_table_args(A) ::= ifnotexists(U) ids(V) cpxName(Z) AS select(S). {
  A = tSetCreateTableInfo(NULL, NULL, S, TSQL_CREATE_STREAM);
  setSqlInfo(pInfo, A, NULL, TSDB_SQL_CREATE_TABLE);

  V.n += Z.n;
  setCreatedTableName(pInfo, &V, &U);
}

%type column{TAOS_FIELD}
%type columnlist{SArray*}
%destructor columnlist {taosArrayDestroy($$);}
columnlist(A) ::= columnlist(X) COMMA column(Y).  {taosArrayPush(X, &Y); A = X;  }
columnlist(A) ::= column(X).                      {A = taosArrayInit(4, sizeof(TAOS_FIELD)); taosArrayPush(A, &X);}

// The information used for a column is the name and type of column:
// tinyint smallint int bigint float double bool timestamp binary(x) nchar(x)
column(A) ::= ids(X) typename(Y).          {
  tSetColumnInfo(&A, &X, &Y);
}

%type tagitemlist {SArray*}
%destructor tagitemlist {taosArrayDestroy($$);}

%type tagitem {tVariant}
tagitemlist(A) ::= tagitemlist(X) COMMA tagitem(Y). { A = tVariantListAppend(X, &Y, -1);    }
tagitemlist(A) ::= tagitem(X).                      { A = tVariantListAppend(NULL, &X, -1); }

tagitem(A) ::= INTEGER(X).      { toTSDBType(X.type); tVariantCreate(&A, &X); }
tagitem(A) ::= FLOAT(X).        { toTSDBType(X.type); tVariantCreate(&A, &X); }
tagitem(A) ::= STRING(X).       { toTSDBType(X.type); tVariantCreate(&A, &X); }
tagitem(A) ::= BOOL(X).         { toTSDBType(X.type); tVariantCreate(&A, &X); }
tagitem(A) ::= NULL(X).         { X.type = 0; tVariantCreate(&A, &X); }
tagitem(A) ::= NOW(X).          { X.type = TSDB_DATA_TYPE_TIMESTAMP; tVariantCreate(&A, &X);}

tagitem(A) ::= MINUS(X) INTEGER(Y).{
    X.n += Y.n;
    X.type = Y.type;
    toTSDBType(X.type);
    tVariantCreate(&A, &X);
}

tagitem(A) ::= MINUS(X) FLOAT(Y).  {
    X.n += Y.n;
    X.type = Y.type;
    toTSDBType(X.type);
    tVariantCreate(&A, &X);
}

tagitem(A) ::= PLUS(X) INTEGER(Y). {
    X.n += Y.n;
    X.type = Y.type;
    toTSDBType(X.type);
    tVariantCreate(&A, &X);
}

tagitem(A) ::= PLUS(X) FLOAT(Y).  {
    X.n += Y.n;
    X.type = Y.type;
    toTSDBType(X.type);
    tVariantCreate(&A, &X);
}

//////////////////////// The SELECT statement /////////////////////////////////
%type select {SSqlNode*}
%destructor select {destroySqlNode($$);}
select(A) ::= SELECT(T) selcollist(W) from(X) where_opt(Y) range_option(R) interval_option(K) sliding_opt(S) session_option(H) windowstate_option(D) fill_opt(F)groupby_opt(P) having_opt(N) orderby_opt(Z) slimit_opt(G) limit_opt(L). {
  A = tSetQuerySqlNode(&T, W, X, Y, P, Z, &K, &H, &D, &S, F, &L, &G, N, &R);
}

select(A) ::= LP select(B) RP. {A = B;}

%type union {SArray*}
%destructor union {destroyAllSqlNode($$);}
union(Y) ::= select(X). { Y = setSubclause(NULL, X); }
union(Y) ::= union(Z) UNION ALL select(X). { Y = appendSelectClause(Z, X); }

cmd ::= union(X). { setSqlInfo(pInfo, X, NULL, TSDB_SQL_SELECT); }

// Support for the SQL exprssion without from & where subclauses, e.g.,
// select database()
// select server_version()
// select client_version()
// select server_state()
select(A) ::= SELECT(T) selcollist(W). {
  A = tSetQuerySqlNode(&T, W, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}

// selcollist is a list of expressions that are to become the return
// values of the SELECT statement.  The "*" in statements like
// "SELECT * FROM ..." is encoded as a special expression with an opcode of TK_ALL.
%type selcollist {SArray*}
%destructor selcollist {tSqlExprListDestroy($$);}

%type sclp {SArray*}
%destructor sclp {tSqlExprListDestroy($$);}
sclp(A) ::= selcollist(X) COMMA.             {A = X;}
sclp(A) ::= .                                {A = 0;}
selcollist(A) ::= sclp(P) distinct(Z) expr(X) as(Y).     {
   A = tSqlExprListAppend(P, X,  Z.n? &Z:0, Y.n?&Y:0);
}

selcollist(A) ::= sclp(P) STAR. {
   tSqlExpr *pNode = tSqlExprCreateIdValue(pInfo, NULL, TK_ALL);
   A = tSqlExprListAppend(P, pNode, 0, 0);
}

// An option "AS <id>" phrase that can follow one of the expressions that
// define the result set, or one of the tables in the FROM clause.
%type as {SStrToken}
as(X) ::= AS ids(Y).    { X = Y;    }
as(X) ::= ids(Y).       { X = Y;    }
as(X) ::= .             { X.n = 0;  }

%type distinct {SStrToken}
distinct(X) ::= DISTINCT(Y). { X = Y;  }
distinct(X) ::= .            { X.n = 0;}

// A complete FROM clause.
%type from {SRelationInfo*}
%destructor from {destroyRelationInfo($$);}
from(A) ::= FROM tablelist(X).                 {A = X;}
from(A) ::= FROM sub(X).                       {A = X;}

%type sub {SRelationInfo*}
%destructor sub {destroyRelationInfo($$);}
sub(A)  ::= LP union(Y) RP.                    {A = addSubqueryElem(NULL, Y, NULL);}
sub(A)  ::= LP union(Y) RP ids(Z).             {A = addSubqueryElem(NULL, Y, &Z);}
sub(A)  ::= sub(X) COMMA LP union(Y) RP ids(Z).{A = addSubqueryElem(X, Y, &Z);}

%type tablelist {SRelationInfo*}
%destructor tablelist {destroyRelationInfo($$);}
tablelist(A) ::= ids(X) cpxName(Y).                     {
  X.n += Y.n;
  A = setTableNameList(NULL, &X, NULL);
}

tablelist(A) ::= ids(X) cpxName(Y) ids(Z).             {
  X.n += Y.n;
  A = setTableNameList(NULL, &X, &Z);
}

tablelist(A) ::= tablelist(Y) COMMA ids(X) cpxName(Z).  {
  X.n += Z.n;
  A = setTableNameList(Y, &X, NULL);
}

tablelist(A) ::= tablelist(Y) COMMA ids(X) cpxName(Z) ids(F). {
  X.n += Z.n;
  A = setTableNameList(Y, &X, &F);
}

// The value of interval should be the form of "number+[a,s,m,h,d,n,y]" or "now"
%type tmvar {SStrToken}
tmvar(A) ::= VARIABLE(X).   {A = X;}


%type timestamp {tSqlExpr*}
%destructor timestamp {tSqlExprDestroy($$);}

timestamp(A) ::= INTEGER(X).          { A = tSqlExprCreateTimestamp(&X, TK_INTEGER);}
timestamp(A) ::= MINUS(X) INTEGER(Y). { X.n += Y.n; X.type = TK_INTEGER; A = tSqlExprCreateTimestamp(&X, TK_INTEGER);}
timestamp(A) ::= PLUS(X)  INTEGER(Y). { X.n += Y.n; X.type = TK_INTEGER; A = tSqlExprCreateTimestamp(&X, TK_INTEGER);}
timestamp(A) ::= STRING(X).           { A = tSqlExprCreateTimestamp(&X, TK_STRING);}
timestamp(A) ::= NOW(X).              { A = tSqlExprCreateTimestamp(&X, TK_NOW); }
timestamp(A) ::= NOW PLUS  VARIABLE(Y).   {A = tSqlExprCreateTimestamp(&Y, TK_PLUS);  }
timestamp(A) ::= NOW MINUS VARIABLE(Y).   {A = tSqlExprCreateTimestamp(&Y, TK_MINUS); }

%type range_option {SRangeVal}
range_option(N) ::= . {N.start = 0; N.end = 0;}
range_option(N) ::= RANGE LP timestamp(E) COMMA timestamp(X) RP. {N.start = E; N.end = X;}

%type interval_option {SIntervalVal}
interval_option(N) ::= intervalKey(A) LP tmvar(E) RP.                {N.interval = E; N.offset.n = 0; N.token = A;}
interval_option(N) ::= intervalKey(A) LP tmvar(E) COMMA tmvar(X) RP. {N.interval = E; N.offset = X;   N.token = A;}
interval_option(N) ::= .                                             {memset(&N, 0, sizeof(N));}

%type intervalKey {int32_t}
intervalKey(A)     ::= INTERVAL.                                     {A = TK_INTERVAL;}
intervalKey(A)     ::= EVERY.                                        {A = TK_EVERY;   }

%type session_option {SSessionWindowVal}
session_option(X) ::= .                                                  {X.col.n = 0; X.gap.n = 0;}
session_option(X) ::= SESSION LP ids(V) cpxName(Z) COMMA tmvar(Y) RP.    {
   V.n += Z.n;
   X.col = V;
   X.gap = Y;
}

%type windowstate_option {SWindowStateVal}
windowstate_option(X) ::= .                                                { X.col.n = 0; X.col.z = NULL;}
windowstate_option(X) ::= STATE_WINDOW LP ids(V) RP.                       { X.col = V; }

%type fill_opt {SArray*}
%destructor fill_opt {taosArrayDestroy($$);}
fill_opt(N) ::= .                                           { N = 0;     }
fill_opt(N) ::= FILL LP ID(Y) COMMA tagitemlist(X) RP.      {
    tVariant A = {0};
    toTSDBType(Y.type);
    tVariantCreate(&A, &Y);

    tVariantListInsert(X, &A, -1, 0);
    N = X;
}

fill_opt(N) ::= FILL LP ID(Y) RP.               {
    toTSDBType(Y.type);
    N = tVariantListAppendToken(NULL, &Y, -1);
}

%type sliding_opt {SStrToken}
sliding_opt(K) ::= SLIDING LP tmvar(E) RP.      {K = E;     }
sliding_opt(K) ::= .                            {K.n = 0; K.z = NULL; K.type = 0;   }

%type orderby_opt {SArray*}
%destructor orderby_opt {taosArrayDestroy($$);}

%type sortlist {SArray*}
%destructor sortlist {taosArrayDestroy($$);}

%type sortitem {tVariant}
%destructor sortitem {tVariantDestroy(&$$);}

orderby_opt(A) ::= .                          {A = 0;}
orderby_opt(A) ::= ORDER BY sortlist(X).      {A = X;}

sortlist(A) ::= sortlist(X) COMMA item(Y) sortorder(Z). {
    A = tVariantListAppend(X, &Y, Z);
}

sortlist(A) ::= item(Y) sortorder(Z). {
  A = tVariantListAppend(NULL, &Y, Z);
}

%type item {tVariant}
item(A) ::= ids(X) cpxName(Y).   {
  toTSDBType(X.type);
  X.n += Y.n;

  tVariantCreate(&A, &X);
}

%type sortorder {int}
sortorder(A) ::= ASC.           { A = TSDB_ORDER_ASC; }
sortorder(A) ::= DESC.          { A = TSDB_ORDER_DESC;}
sortorder(A) ::= .              { A = TSDB_ORDER_ASC; }  // Ascending order by default

//group by clause
%type groupby_opt {SArray*}
%destructor groupby_opt {taosArrayDestroy($$);}
%type grouplist {SArray*}
%destructor grouplist {taosArrayDestroy($$);}

groupby_opt(A) ::= .                       { A = 0;}
groupby_opt(A) ::= GROUP BY grouplist(X).  { A = X;}

grouplist(A) ::= grouplist(X) COMMA item(Y).    {
  A = tVariantListAppend(X, &Y, -1);
}

grouplist(A) ::= item(X).                       {
  A = tVariantListAppend(NULL, &X, -1);
}

//having clause, ignore the input condition in having
%type having_opt {tSqlExpr*}
%destructor having_opt {tSqlExprDestroy($$);}
having_opt(A) ::=.                  {A = 0;}
having_opt(A) ::= HAVING expr(X).   {A = X;}

//limit-offset subclause
%type limit_opt {SLimitVal}
limit_opt(A) ::= .                     {A.limit = -1; A.offset = 0;}
limit_opt(A) ::= LIMIT signed(X).      {A.limit = X;  A.offset = 0;}
limit_opt(A) ::= LIMIT signed(X) OFFSET signed(Y).
                                       { A.limit = X;  A.offset = Y;}
limit_opt(A) ::= LIMIT signed(X) COMMA signed(Y).
                                       { A.limit = Y;  A.offset = X;}

%type slimit_opt {SLimitVal}
slimit_opt(A) ::= .                    {A.limit = -1; A.offset = 0;}
slimit_opt(A) ::= SLIMIT signed(X).    {A.limit = X;  A.offset = 0;}
slimit_opt(A) ::= SLIMIT signed(X) SOFFSET signed(Y).
                                       {A.limit = X;  A.offset = Y;}
slimit_opt(A) ::= SLIMIT signed(X) COMMA  signed(Y).
                                       {A.limit = Y;  A.offset = X;}

%type where_opt {tSqlExpr*}
%destructor where_opt {tSqlExprDestroy($$);}

where_opt(A) ::= .                    {A = 0;}
where_opt(A) ::= WHERE expr(X).       {A = X;}

/////////////////////////// Expression Processing /////////////////////////////
//
%type expr {tSqlExpr*}
%destructor expr {tSqlExprDestroy($$);}

expr(A) ::= LP(X) expr(Y) RP(Z).       {A = Y; A->exprToken.z = X.z; A->exprToken.n = (Z.z - X.z + 1);}

expr(A) ::= ID(X).               { A = tSqlExprCreateIdValue(pInfo, &X, TK_ID);}
expr(A) ::= ID(X) DOT ID(Y).     { X.n += (1+Y.n); A = tSqlExprCreateIdValue(pInfo, &X, TK_ID);}
expr(A) ::= ID(X) DOT STAR(Y).   { X.n += (1+Y.n); A = tSqlExprCreateIdValue(pInfo, &X, TK_ALL);}

expr(A) ::= INTEGER(X).          { A = tSqlExprCreateIdValue(pInfo, &X, TK_INTEGER);}
expr(A) ::= MINUS(X) INTEGER(Y). { X.n += Y.n; X.type = TK_INTEGER; A = tSqlExprCreateIdValue(pInfo, &X, TK_INTEGER);}
expr(A) ::= PLUS(X)  INTEGER(Y). { X.n += Y.n; X.type = TK_INTEGER; A = tSqlExprCreateIdValue(pInfo, &X, TK_INTEGER);}
expr(A) ::= FLOAT(X).            { A = tSqlExprCreateIdValue(pInfo, &X, TK_FLOAT);}
expr(A) ::= MINUS(X) FLOAT(Y).   { X.n += Y.n; X.type = TK_FLOAT; A = tSqlExprCreateIdValue(pInfo, &X, TK_FLOAT);}
expr(A) ::= PLUS(X) FLOAT(Y).    { X.n += Y.n; X.type = TK_FLOAT; A = tSqlExprCreateIdValue(pInfo, &X, TK_FLOAT);}
expr(A) ::= STRING(X).           { A = tSqlExprCreateIdValue(pInfo, &X, TK_STRING);}
expr(A) ::= NOW(X).              { A = tSqlExprCreateIdValue(pInfo, &X, TK_NOW); }
expr(A) ::= VARIABLE(X).         { A = tSqlExprCreateIdValue(pInfo, &X, TK_VARIABLE);}
expr(A) ::= PLUS(X) VARIABLE(Y).   { X.n += Y.n; X.type = TK_VARIABLE; A = tSqlExprCreateIdValue(pInfo, &X, TK_VARIABLE);}
expr(A) ::= MINUS(X) VARIABLE(Y).  { X.n += Y.n; X.type = TK_VARIABLE; A = tSqlExprCreateIdValue(pInfo, &X, TK_VARIABLE);}
expr(A) ::= BOOL(X).             { A = tSqlExprCreateIdValue(pInfo, &X, TK_BOOL);}
expr(A) ::= NULL(X).             { A = tSqlExprCreateIdValue(pInfo, &X, TK_NULL);}

// ordinary functions: min(x), max(x), top(k, 20)
expr(A) ::= ID(X) LP exprlist(Y) RP(E). { tStrTokenAppend(pInfo->funcs, &X); A = tSqlExprCreateFunction(Y, &X, &E, X.type); }

// for parsing sql functions with wildcard for parameters. e.g., count(*)/first(*)/last(*) operation
expr(A) ::= ID(X) LP STAR RP(Y).     { tStrTokenAppend(pInfo->funcs, &X); A = tSqlExprCreateFunction(NULL, &X, &Y, X.type); }

// is (not) null expression
expr(A) ::= expr(X) IS NULL.           {A = tSqlExprCreate(X, NULL, TK_ISNULL);}
expr(A) ::= expr(X) IS NOT NULL.       {A = tSqlExprCreate(X, NULL, TK_NOTNULL);}

// relational expression
expr(A) ::= expr(X) LT expr(Y).      {A = tSqlExprCreate(X, Y, TK_LT);}
expr(A) ::= expr(X) GT expr(Y).      {A = tSqlExprCreate(X, Y, TK_GT);}
expr(A) ::= expr(X) LE expr(Y).      {A = tSqlExprCreate(X, Y, TK_LE);}
expr(A) ::= expr(X) GE expr(Y).      {A = tSqlExprCreate(X, Y, TK_GE);}
expr(A) ::= expr(X) NE expr(Y).      {A = tSqlExprCreate(X, Y, TK_NE);}
expr(A) ::= expr(X) EQ expr(Y).      {A = tSqlExprCreate(X, Y, TK_EQ);}

expr(A) ::= expr(X) BETWEEN expr(Y) AND expr(Z).      { tSqlExpr* X2 = tSqlExprClone(X); A = tSqlExprCreate(tSqlExprCreate(X, Y, TK_GE), tSqlExprCreate(X2, Z, TK_LE), TK_AND);}

expr(A) ::= expr(X) AND expr(Y).     {A = tSqlExprCreate(X, Y, TK_AND);}
expr(A) ::= expr(X) OR  expr(Y).     {A = tSqlExprCreate(X, Y, TK_OR); }

// binary arithmetic expression
expr(A) ::= expr(X) PLUS  expr(Y).   {A = tSqlExprCreate(X, Y, TK_PLUS);  }
expr(A) ::= expr(X) MINUS expr(Y).   {A = tSqlExprCreate(X, Y, TK_MINUS); }
expr(A) ::= expr(X) STAR  expr(Y).   {A = tSqlExprCreate(X, Y, TK_STAR);  }
expr(A) ::= expr(X) SLASH expr(Y).   {A = tSqlExprCreate(X, Y, TK_DIVIDE);}
expr(A) ::= expr(X) REM   expr(Y).   {A = tSqlExprCreate(X, Y, TK_REM);   }

// like expression
expr(A) ::= expr(X) LIKE expr(Y).    {A = tSqlExprCreate(X, Y, TK_LIKE);  }

// match expression
expr(A) ::= expr(X) MATCH expr(Y).    {A = tSqlExprCreate(X, Y, TK_MATCH);  }
expr(A) ::= expr(X) NMATCH expr(Y).    {A = tSqlExprCreate(X, Y, TK_NMATCH);  }

//in expression
expr(A) ::= expr(X) IN LP exprlist(Y) RP.   {A = tSqlExprCreate(X, (tSqlExpr*)Y, TK_IN); }

%type exprlist {SArray*}
%destructor exprlist {tSqlExprListDestroy($$);}

%type expritem {tSqlExpr*}
%destructor expritem {tSqlExprDestroy($$);}

exprlist(A) ::= exprlist(X) COMMA expritem(Y). {A = tSqlExprListAppend(X,Y,0, 0);}
exprlist(A) ::= expritem(X).                   {A = tSqlExprListAppend(0,X,0, 0);}
expritem(A) ::= expr(X).                       {A = X;}
expritem(A) ::= .                              {A = 0;}

///////////////////////////////////reset query cache//////////////////////////////////////
cmd ::= RESET QUERY CACHE.  { setDCLSqlElems(pInfo, TSDB_SQL_RESET_CACHE, 0);}

///////////////////////////////////sync replica database//////////////////////////////////
cmd ::= SYNCDB ids(X) REPLICA.{ setDCLSqlElems(pInfo, TSDB_SQL_SYNC_DB_REPLICA, 1, &X);}

///////////////////////////////////ALTER TABLE statement//////////////////////////////////
cmd ::= ALTER TABLE ids(X) cpxName(F) ADD COLUMN columnlist(A).     {
    X.n += F.n;
    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, A, NULL, TSDB_ALTER_TABLE_ADD_COLUMN, -1);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER TABLE ids(X) cpxName(F) DROP COLUMN ids(A).     {
    X.n += F.n;

    toTSDBType(A.type);
    SArray* K = tVariantListAppendToken(NULL, &A, -1);

    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, NULL, K, TSDB_ALTER_TABLE_DROP_COLUMN, -1);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER TABLE ids(X) cpxName(F) MODIFY COLUMN columnlist(A).     {
    X.n += F.n;
    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, A, NULL, TSDB_ALTER_TABLE_CHANGE_COLUMN, -1);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

//////////////////////////////////ALTER TAGS statement/////////////////////////////////////
cmd ::= ALTER TABLE ids(X) cpxName(Y) ADD TAG columnlist(A).        {
    X.n += Y.n;
    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, A, NULL, TSDB_ALTER_TABLE_ADD_TAG_COLUMN, -1);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}
cmd ::= ALTER TABLE ids(X) cpxName(Z) DROP TAG ids(Y).          {
    X.n += Z.n;

    toTSDBType(Y.type);
    SArray* A = tVariantListAppendToken(NULL, &Y, -1);

    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, NULL, A, TSDB_ALTER_TABLE_DROP_TAG_COLUMN, -1);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER TABLE ids(X) cpxName(F) CHANGE TAG ids(Y) ids(Z). {
    X.n += F.n;

    toTSDBType(Y.type);
    SArray* A = tVariantListAppendToken(NULL, &Y, -1);

    toTSDBType(Z.type);
    A = tVariantListAppendToken(A, &Z, -1);

    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, NULL, A, TSDB_ALTER_TABLE_CHANGE_TAG_COLUMN, -1);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER TABLE ids(X) cpxName(F) SET TAG ids(Y) EQ tagitem(Z).     {
    X.n += F.n;

    toTSDBType(Y.type);
    SArray* A = tVariantListAppendToken(NULL, &Y, -1);
    A = tVariantListAppend(A, &Z, -1);

    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, NULL, A, TSDB_ALTER_TABLE_UPDATE_TAG_VAL, -1);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER TABLE ids(X) cpxName(F) MODIFY TAG columnlist(A).     {
    X.n += F.n;
    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, A, NULL, TSDB_ALTER_TABLE_MODIFY_TAG_COLUMN, -1);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

///////////////////////////////////ALTER STABLE statement//////////////////////////////////
cmd ::= ALTER STABLE ids(X) cpxName(F) ADD COLUMN columnlist(A).     {
    X.n += F.n;
    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, A, NULL, TSDB_ALTER_TABLE_ADD_COLUMN, TSDB_SUPER_TABLE);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER STABLE ids(X) cpxName(F) DROP COLUMN ids(A).     {
    X.n += F.n;

    toTSDBType(A.type);
    SArray* K = tVariantListAppendToken(NULL, &A, -1);

    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, NULL, K, TSDB_ALTER_TABLE_DROP_COLUMN, TSDB_SUPER_TABLE);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER STABLE ids(X) cpxName(F) MODIFY COLUMN columnlist(A).     {
    X.n += F.n;
    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, A, NULL, TSDB_ALTER_TABLE_CHANGE_COLUMN, TSDB_SUPER_TABLE);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

//////////////////////////////////ALTER TAGS statement/////////////////////////////////////
cmd ::= ALTER STABLE ids(X) cpxName(Y) ADD TAG columnlist(A).        {
    X.n += Y.n;
    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, A, NULL, TSDB_ALTER_TABLE_ADD_TAG_COLUMN, TSDB_SUPER_TABLE);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}
cmd ::= ALTER STABLE ids(X) cpxName(Z) DROP TAG ids(Y).          {
    X.n += Z.n;

    toTSDBType(Y.type);
    SArray* A = tVariantListAppendToken(NULL, &Y, -1);

    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, NULL, A, TSDB_ALTER_TABLE_DROP_TAG_COLUMN, TSDB_SUPER_TABLE);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER STABLE ids(X) cpxName(F) CHANGE TAG ids(Y) ids(Z). {
    X.n += F.n;

    toTSDBType(Y.type);
    SArray* A = tVariantListAppendToken(NULL, &Y, -1);

    toTSDBType(Z.type);
    A = tVariantListAppendToken(A, &Z, -1);

    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, NULL, A, TSDB_ALTER_TABLE_CHANGE_TAG_COLUMN, TSDB_SUPER_TABLE);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER STABLE ids(X) cpxName(F) SET TAG ids(Y) EQ tagitem(Z).     {
    X.n += F.n;

    toTSDBType(Y.type);
    SArray* A = tVariantListAppendToken(NULL, &Y, -1);
    A = tVariantListAppend(A, &Z, -1);

    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, NULL, A, TSDB_ALTER_TABLE_UPDATE_TAG_VAL, TSDB_SUPER_TABLE);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER STABLE ids(X) cpxName(F) MODIFY TAG columnlist(A).     {
    X.n += F.n;
    SAlterTableInfo* pAlterTable = tSetAlterTableInfo(&X, A, NULL, TSDB_ALTER_TABLE_MODIFY_TAG_COLUMN, TSDB_SUPER_TABLE);
    setSqlInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

////////////////////////////////////////kill statement///////////////////////////////////////
cmd ::= KILL CONNECTION INTEGER(Y).   {setKillSql(pInfo, TSDB_SQL_KILL_CONNECTION, &Y);}
cmd ::= KILL STREAM INTEGER(X) COLON(Z) INTEGER(Y).       {X.n += (Z.n + Y.n); setKillSql(pInfo, TSDB_SQL_KILL_STREAM, &X);}
cmd ::= KILL QUERY INTEGER(X) COLON(Z) INTEGER(Y).        {X.n += (Z.n + Y.n); setKillSql(pInfo, TSDB_SQL_KILL_QUERY, &X);}

%fallback ID ABORT AFTER ASC ATTACH BEFORE BEGIN CASCADE CLUSTER CONFLICT COPY DATABASE DEFERRED
  DELIMITERS DESC DETACH EACH END EXPLAIN FAIL FOR GLOB IGNORE IMMEDIATE INITIALLY INSTEAD
  LIKE MATCH NMATCH KEY OF OFFSET RAISE REPLACE RESTRICT ROW STATEMENT TRIGGER VIEW ALL
  NOW IPTOKEN SEMI NONE PREV LINEAR IMPORT TBNAME JOIN STABLE NULL INSERT INTO VALUES FILE.
