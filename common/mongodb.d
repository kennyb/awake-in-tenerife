module mongodb;

private import tango.stdc.posix.netinet.in_;

extern(C):

// mongo_except.h

/* always non-zero */
/*
typedef enum{
    MONGO_EXCEPT_NETWORK=1,
    MONGO_EXCEPT_FIND_ERR
}mongo_exception_type;


typedef struct {
	jmp_buf base_handler;
	jmp_buf *penv;
	int caught;
	volatile mongo_exception_type type;
};
*/

// mongo.h

struct mongo_connection_options {
	char[255] host;
	int port;
};

struct mongo_connection {
	mongo_connection_options* left_opts; /* always current server */
	mongo_connection_options* right_opts; /* unused with single server */
	sockaddr_in sa;
	socklen_t addressSize;
	int sock;
	bool connected;
	char padding_for_exception[24];
	//mongo_exception_context exception;
};


struct mongo_header {
	align(1):
	int len;
	int id;
	int responseTo;
	int op;
};

struct mongo_message {
	align(1):
	mongo_header head;
	char data;
};

struct mongo_reply_fields {
	align(1):
	int flag; /* non-zero on failure */
	long cursorID;
	int start;
	int num;
};

struct mongo_reply {
	align(1):
	mongo_header head;
	mongo_reply_fields fields;
	char objs;
};

struct mongo_cursor {
	mongo_reply * mm; /* message is owned by cursor */
	mongo_connection * conn; /* connection is *not* owned by cursor */
	/*const*/ char* ns; /* owned by cursor */
	bson current;
};

enum mongo_operations {
	mongo_op_msg = 1000,    /* generic msg command followed by a string */
	mongo_op_update = 2001, /* update object */
	mongo_op_insert = 2002,
	mongo_op_query = 2004,
	mongo_op_get_more = 2005,
	mongo_op_delete = 2006,
	mongo_op_kill_cursors = 2007
};


/* ----------------------------
CONNECTION STUFF
------------------------------ */

enum mongo_conn_return {
	mongo_conn_success = 0,
	mongo_conn_bad_arg,
	mongo_conn_no_socket,
	mongo_conn_fail,
	mongo_conn_not_master /* leaves conn connected to slave */
};

/**
* @param options can be null
*/
mongo_conn_return mongo_connect( mongo_connection * conn , mongo_connection_options * options );
mongo_conn_return mongo_connect_pair( mongo_connection * conn , mongo_connection_options * left, mongo_connection_options * right );
mongo_conn_return mongo_reconnect( mongo_connection * conn ); /* you will need to reauthenticate after calling */
bool mongo_disconnect( mongo_connection * conn ); /* use this if you want to be able to reconnect */
bool mongo_destroy( mongo_connection * conn ); /* you must call this even if connection failed */



/* ----------------------------
CORE METHODS - insert update remove query getmore
------------------------------ */

void mongo_insert( mongo_connection * conn , /*const*/ char * ns , bson * data );
void mongo_insert_batch( mongo_connection * conn , /*const*/ char * ns , bson ** data , int num );

const int MONGO_UPDATE_UPSERT = 0x1;
const int MONGO_UPDATE_MULTI = 0x2;
void mongo_update(mongo_connection* conn, /*const*/ char* ns, /*const*/ bson* cond, /*const*/ bson* op, int flags);

void mongo_remove(mongo_connection* conn, /*const*/ char* ns, /*const*/ bson* cond);

mongo_cursor* mongo_find(mongo_connection* conn, /*const*/ char* ns, bson* query, bson* fields ,int nToReturn ,int nToSkip, int options);
bool mongo_cursor_next(mongo_cursor* cursor);
void mongo_cursor_destroy(mongo_cursor* cursor);

/* result can be NULL if you don't care about results. useful for commands */
bool mongo_find_one(mongo_connection* conn, /*const*/ char* ns, bson* query, bson* fields, bson* result);

long mongo_count(mongo_connection* conn, /*const*/ char* db, /*const*/ char* coll, bson* query);

/* ----------------------------
HIGHER LEVEL - indexes - command helpers eval
------------------------------ */

/* Returns true on success */
/* WARNING: Unlike other drivers these do not cache results */

static /*const*/ int MONGO_INDEX_UNIQUE = 0x1;
static /*const*/ int MONGO_INDEX_DROP_DUPS = 0x2;
bool mongo_create_index(mongo_connection * conn, /*const*/ char * ns, bson * key, int options, bson * result);
bool mongo_create_simple_index(mongo_connection * conn, /*const*/ char * ns, /*const*/ char* field, int options, bson * result);

/* ----------------------------
COMMANDS
------------------------------ */

bool mongo_run_command(mongo_connection * conn, /*const*/ char * db, bson * command, bson * result);

/* for simple commands with a single k-v pair */
bool mongo_simple_int_command(mongo_connection * conn, /*const*/ char * db, /*const*/ char* cmd,         int arg, bson * result);
bool mongo_simple_str_command(mongo_connection * conn, /*const*/ char * db, /*const*/ char* cmd, /*const*/ char* arg, bson * result);

bool mongo_cmd_drop_db(mongo_connection * conn, /*const*/ char * db);
bool mongo_cmd_drop_collection(mongo_connection * conn, /*const*/ char * db, /*const*/ char * collection, bson * result);

void mongo_cmd_add_user(mongo_connection* conn, /*const*/ char* db, /*const*/ char* user, /*const*/ char* pass);
bool mongo_cmd_authenticate(mongo_connection* conn, /*const*/ char* db, /*const*/ char* user, /*const*/ char* pass);

/* return value is master status */
bool mongo_cmd_ismaster(mongo_connection * conn, bson * result);

/* true return indicates error */
bool mongo_cmd_get_last_error(mongo_connection * conn, /*const*/ char * db, bson * result);
bool mongo_cmd_get_prev_error(mongo_connection * conn, /*const*/ char * db, bson * result);
void mongo_cmd_reset_error(mongo_connection * conn, /*const*/ char * db);


// bson.h
//------------

enum bson_type {
	bson_eoo=0,
	bson_double=1,
	bson_string=2,
	bson_object=3,
	bson_array=4,
	bson_bindata=5,
	bson_undefined=6,
	bson_oid=7,
	bson_bool=8,
	bson_date=9,
	bson_null=10,
	bson_regex=11,
	bson_dbref=12, /* deprecated */
	bson_code=13,
	bson_symbol=14,
	bson_codewscope=15,
	bson_int = 16,
	bson_timestamp = 17,
	bson_long = 18
};

typedef int bson_bool_t;

struct bson {
	char * data;
	bson_bool_t owned;
};

struct bson_iterator {
	/*const*/ char * cur;
	bson_bool_t first;
};

struct bson_buffer {
	char * buf;
	char * cur;
	int bufSize;
	bson_bool_t finished;
	int stack[32];
	int stackPos;
};

union bson_oid_t {
	align(1):
	char bytes[12];
	int ints[3];
};

typedef long bson_date_t; /* milliseconds since epoch UTC */

/* ----------------------------
READING
------------------------------ */


bson * bson_empty(bson * obj); /* returns pointer to static empty bson object */
void bson_copy(bson * dest, /*const*/ bson* src); /* puts data in new buffer. NOOP if out==NULL */
bson * bson_from_buffer(bson * b, bson_buffer * buf);
bson * bson_init( bson * b , char * data , bson_bool_t mine );
int bson_size(/*const*/ bson * b );
void bson_destroy( bson * b );

void bson_print( bson * b );
void bson_print_raw( /*const*/ char * bson , int depth );

/* advances iterator to named field */
/* returns bson_eoo (which is false) if field not found */
bson_type bson_find(bson_iterator* it, /*const*/ bson* obj, /*const*/ char* name);

void bson_iterator_init( bson_iterator * i , /*const*/ char * bson );

/* more returns true for eoo. best to loop with bson_iterator_next(&it) */
bson_bool_t bson_iterator_more( /*const*/ bson_iterator * i );
bson_type bson_iterator_next( bson_iterator * i );

bson_type bson_iterator_type( /*const*/ bson_iterator * i );
/*const*/ char * bson_iterator_key( /*const*/ bson_iterator * i );
/*const*/ char * bson_iterator_value( /*const*/ bson_iterator * i );

/* these convert to the right type (return 0 if non-numeric) */
double bson_iterator_double( /*const*/ bson_iterator * i );
int bson_iterator_int( /*const*/ bson_iterator * i );
long bson_iterator_long( /*const*/ bson_iterator * i );

/* false: boolean false, 0 in any type, or null */
/* true: anything else (even empty strings and objects) */
bson_bool_t bson_iterator_bool( /*const*/ bson_iterator * i );

/* these assume you are using the right type */
double bson_iterator_double_raw( /*const*/ bson_iterator * i );
int bson_iterator_int_raw( /*const*/ bson_iterator * i );
long bson_iterator_long_raw( /*const*/ bson_iterator * i );
bson_bool_t bson_iterator_bool_raw( /*const*/ bson_iterator * i );
bson_oid_t* bson_iterator_oid( /*const*/ bson_iterator * i );

/* these can also be used with bson_code and bson_symbol*/
/*const*/ char * bson_iterator_string( /*const*/ bson_iterator * i );
int bson_iterator_string_len( /*const*/ bson_iterator * i );

/* works with bson_code, bson_codewscope, and bson_string */
/* returns NULL for everything else */
/*const*/ char * bson_iterator_code(/*const*/ bson_iterator * i);

/* calls bson_empty on scope if not a bson_codewscope */
void bson_iterator_code_scope(/*const*/ bson_iterator * i, bson * code_scope);

/* both of these only work with bson_date */
bson_date_t bson_iterator_date(/*const*/ bson_iterator * i);
time_t bson_iterator_time_t(/*const*/ bson_iterator * i);

int bson_iterator_bin_len( /*const*/ bson_iterator * i );
char bson_iterator_bin_type( /*const*/ bson_iterator * i );
/*const*/ char * bson_iterator_bin_data( /*const*/ bson_iterator * i );

/*const*/ char * bson_iterator_regex( /*const*/ bson_iterator * i );
/*const*/ char * bson_iterator_regex_opts( /*const*/ bson_iterator * i );

/* these work with bson_object and bson_array */
void bson_iterator_subobject(/*const*/ bson_iterator * i, bson * sub);
void bson_iterator_subiterator(/*const*/ bson_iterator * i, bson_iterator * sub);

/* str must be at least 24 hex chars + null byte */
void bson_oid_from_string(bson_oid_t* oid, /*const*/ char* str);
void bson_oid_to_string(/*const*/ bson_oid_t* oid, char* str);
void bson_oid_gen(bson_oid_t* oid);

time_t bson_oid_generated_time(bson_oid_t* oid); /* Gives the time the OID was created */

/* ----------------------------
BUILDING
------------------------------ */

bson_buffer * bson_buffer_init( bson_buffer * b );
//bson_buffer * bson_ensure_space( bson_buffer * b , /*const*/ int bytesNeeded );

/**
* @return the raw data.  you either should free this OR call bson_destroy not both
*/
char * bson_buffer_finish( bson_buffer * b );
void bson_buffer_destroy( bson_buffer * b );

bson_buffer * bson_append_oid( bson_buffer * b , /*const*/ char * name , /*const*/ bson_oid_t* oid );
bson_buffer * bson_append_new_oid( bson_buffer * b , /*const*/ char * name );
bson_buffer * bson_append_int( bson_buffer * b , /*const*/ char * name , /*const*/ int i );
bson_buffer * bson_append_long( bson_buffer * b , /*const*/ char * name , /*const*/ long i );
bson_buffer * bson_append_double( bson_buffer * b , /*const*/ char * name , /*const*/ double d );
bson_buffer * bson_append_string( bson_buffer * b , /*const*/ char * name , /*const*/ char * str );
bson_buffer * bson_append_substr( bson_buffer * b , /*const*/ char * name , /*const*/ char * str, int len );
bson_buffer * bson_append_symbol( bson_buffer * b , /*const*/ char * name , /*const*/ char * str );
bson_buffer * bson_append_code( bson_buffer * b , /*const*/ char * name , /*const*/ char * str );
bson_buffer * bson_append_code_w_scope( bson_buffer * b , /*const*/ char * name , /*const*/ char * code , /*const*/ bson * w_scope);
bson_buffer * bson_append_binary( bson_buffer * b, /*const*/ char * name, char type, /*const*/ char * str, int len );
bson_buffer * bson_append_bool( bson_buffer * b , /*const*/ char * name , /*const*/ bson_bool_t v );
bson_buffer * bson_append_null( bson_buffer * b , /*const*/ char * name );
bson_buffer * bson_append_undefined( bson_buffer * b , /*const*/ char * name );
bson_buffer * bson_append_regex( bson_buffer * b , /*const*/ char * name , /*const*/ char * pattern, /*const*/ char * opts );
bson_buffer * bson_append_bson( bson_buffer * b , /*const*/ char * name , /*const*/ bson* bson);
bson_buffer * bson_append_element( bson_buffer * b, /*const*/ char * name_or_null, /*const*/ bson_iterator* elem);

/* these both append a bson_date */
bson_buffer * bson_append_date(bson_buffer * b, /*const*/ char * name, bson_date_t millis);
bson_buffer * bson_append_time_t(bson_buffer * b, /*const*/ char * name, time_t secs);

bson_buffer * bson_append_start_object( bson_buffer * b , /*const*/ char * name );
bson_buffer * bson_append_start_array( bson_buffer * b , /*const*/ char * name );
bson_buffer * bson_append_finish_object( bson_buffer * b );

void bson_numstr(char* str, int i);
void bson_incnumstr(char* str);


/* ------------------------------
ERROR HANDLING - also used in mongo code
------------------------------ */

void * bson_malloc(int size); /* checks return value */

/* bson_err_handlers shouldn't return!!! */
//typedef void(*bson_err_handler)(/*const*/ char* errmsg);

/* returns old handler or NULL */
/* default handler prints error then exits with failure*/
//bson_err_handler set_bson_err_handler(bson_err_handler func);



/* does nothing is ok != 0 */
void bson_fatal( int ok );
void bson_fatal_msg( int ok, /*const*/ char* msg );





