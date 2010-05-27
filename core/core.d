module core;

import tango.stdc.stdio;
import tango.stdc.signal;
import tango.stdc.stdlib : exit, malloc;
import tango.stdc.string;
import tango.stdc.posix.signal;
import tango.stdc.time : time;
import Integer = tango.text.convert.Integer;
import Ascii = tango.text.Ascii;
//import File = tango.io.device.File;
import tango.io.device.File : File;
import tango.io.FilePath : FilePath;
import FileScan = tango.io.FileScan;
import FileSystem = tango.io.FileSystem;
import Path = tango.io.Path;
import tango.sys.Process : Process, ProcessCreateException;
import tango.sys.Environment : Environment;
//import tango.io.compress.c.zlib;

// need a higher version of tango for this
//import tango.core.tools.TraceExceptions;

version(build) pragma(link, "z");
extern(C) int compress2(char* dest, size_t* destLen, /*const*/ char* source, uint sourceLen, int level);

import libowfat;
import externs;

import lib;
import panel;
import shared;
import session;
import edb;

//import edb : edb_init;
extern(C) {
	void create_default_objects();
	//void edb_init(string host = "127.0.0.1", int port = 27017, string db = "test");
	//void RUN_UNITTESTS();
}


/*
standalone application to hook my MVC... that way I can debug it and everything

I don't really want to talk about the details ... we'll code name it furry

i3d.nl -- rackspace

-----------------------------

TODO! - make sure that prt() can dynamically find out the type of the object passed to it and appropriately select the print function...
TODO!! - set the headers to be utf-8
TODO! - change POST to be two string[]'s and make a function called POST that returns the string of the post, or null... so I don't have to do ptr_lala
TODO!! - Make the core code to be able to pass the session through the url or post -- to allow for cookieless browsing
TODO!!! - unit tests for the columns in a loop
OPTIMIZE! - use nedmalloc
OPTIMIZE! - use Judy for hashtables... http://www.nothings.org/computer/judy/

Main: contains the functions to load up the MVC.

reload_panels();
load_panel(string panel);

http://www.youtube.com/watch?v=61ThRHYFQvU

http://youtube.com/watch?v=-iVKltsAKKk

joax:
http://www.youtube.com/watch?v=x4JNpmLPvcY
http://www.youtube.com/watch?v=-cQUO7KndCs

luke:
http://www.youtube.com/watch?v=Hk3LHHOlm6o
http://www.youtube.com/watch?v=GUAO7OaGKxU


Max Ruby - RU Grooves

Man, how good would a cheese sandwich sound right now? con Jamon!

I need a mixto!

*/

/*

Changes to memcache:

1. rewrite memcache interface, to allow for memcache data duplication to account for very high load and vertical failover (but double the amount of sockets needed for writes)
2. branch the memcache code, making memcache-lite -- for use with a binary interface
3. add to memcache sets with a hash level... the logic is, the data can only be overwritten if the hash matches the old data
4. remove the break statement in do_item_alloc (to remove the bottom 50 items -- because it's possible the new item is bigger than the item your evicting)
5. create an interface for a memcache server to come online and grab all of the data out of the other slave and write it into the new memcache server.
	The logic is:
	a. server comes online in write only mode
	b. grab the item(hash) list and the server time from the other server
	c. check if the server has the item. if it doesn't, ask the other server for the item.
	d. evictions can cause problems though, when both servers evict different items, so ask the other server to evict the bottom 5% of it's cache, then send the item list from the bottom up, until the item time is the same as the start time. (to place them in the same order)
	e. server comes online for read and write.
6. create an interface to set the memory use threshold -- so I can query the servers and find all items that haven't been accessed in a long time.. to make sure that evictions are only on items that have no pointer.
7. perhaps, when knowing the primary keys, I can assign different ranges to different servers. That range stays persistient forever, and never changes... new servers can request new blocks of data. I can flush a block from memcache, if I need

When implementing the D memcache, make sure to convert all strings to two shorts... This limits the object size to 64KB, but honestly, I think that's enough for anything...

[2 bytes ][ 2 bytes]
[ offset ][ length ]

struct {
	int var1;
	int var2;
	string var3 = "hey how's it going";
	int var4;
}

Looks like this...

[(4) var1][(4) var2][(2) var3 offset = 16][(2) var3 length = 18][(18)hey how's it going]


*/

enum BROWSER {
	MSIE = 1,
	MOZILLA,
	OPERA,
	SAFARI,
	VALIDATOR,
	OTHER = 100,
}

// global vars

user[uint] users;
uint[][uint] user_won;


extern(C) void sig_handler(int sig) {
	stdoutln("caught signal... ", sig);
}

bool terminating = false;
extern(C) void term_handler(int sig) {
	if(terminating == false) {
		stdoutln("signal ", sig, " caught...");
		terminating = true;
		terminate();
	}
}

void terminate() {
	Core.terminate();
	
	// D termination (since we can't really make main() return):
	_moduleDtor();
	//gc_term();
	version(linux) {
		_STD_critical_term();
		_STD_monitor_staticdtor();
	}
	
	exit(0);
}


enum {
	//TODO(0.2) - as well as a hard limit of number of connections, additionally count the number of connections not yet writing waiting before connecting
	MAX_CONNECTIONS = 200,
	SECONDS_TO_RECONNECT = 5, //TODO!! - change this to 2 seconds for production
	GC_INTERVAL = 1,
	TEMPLATE_MAX_LINES = 20000,
}


void prt(in string str) {
	auto len = str.length;
	auto offset = out_ptr;
	out_ptr += len;
	if(out_ptr < buffer_size) {
		memcpy(&out_tmp[offset], str.ptr, len);
	} else {
		stdoutln("BUFFER OVERFLOW!!!");
		out_ptr -= len;
		assert(false);
	}
}

void prt_conn(in string str) {
	auto len = str.length;
	memcpy(cur_conn.output + cur_conn.output_len, str.ptr, len);;
	cur_conn.output_len += len;
}

void prt_conn(ulong number) {
	string str = Integer.toString(cast(long) number);
	auto len = str.length;
	
	memcpy(cur_conn.output + cur_conn.output_len, str.ptr, len);;
	cur_conn.output_len += len;
}

void prt_html(string str) {
	
	//foreach(i; 0 .. str.length) {
	auto len = str.length;
	for(uint i = 0; i < len; i++) {
		if(str[i] == '>') {
			out_tmp[out_ptr++] = '&';
			out_tmp[out_ptr++] = 'g';
			out_tmp[out_ptr++] = 't';
			out_tmp[out_ptr++] = ';';
		} else if(str[i] == '<') {
			out_tmp[out_ptr++] = '&';
			out_tmp[out_ptr++] = 'l';
			out_tmp[out_ptr++] = 't';
			out_tmp[out_ptr++] = ';';
		} else if(str[i] == '&') {
			out_tmp[out_ptr++] = '&';
			out_tmp[out_ptr++] = 'a';
			out_tmp[out_ptr++] = 'm';
			out_tmp[out_ptr++] = 'p';
			out_tmp[out_ptr++] = ';';
		} else if(str[i] == '\n') {
			out_tmp[out_ptr++] = '<';
			out_tmp[out_ptr++] = 'b';
			out_tmp[out_ptr++] = 'r';
			out_tmp[out_ptr++] = '/';
			out_tmp[out_ptr++] = '>';
		} else {
			out_tmp[out_ptr++] = str[i];
		}
	}
}

void prt_esc(string str) {
	
	//foreach(i; 0 .. str.length) {
	auto len = str.length;
	for(uint i = 0; i < len; i++) {
		if(str[i] == '"') {
			out_tmp[out_ptr++] = '\\';
			out_tmp[out_ptr++] = '"';
		} else if(str[i] == '\\') {
			out_tmp[out_ptr++] = '\\';
			out_tmp[out_ptr++] = '\\';
		} else {
			out_tmp[out_ptr++] = str[i];
		}
	}
}

void prt_esc_html(string str) {
	
	//foreach(i; 0 .. str.length) {
	auto len = str.length;
	for(uint i = 0; i < len; i++) {
		if(str[i] == '"') {
			out_tmp[out_ptr++] = '\\';
			out_tmp[out_ptr++] = '"';
		} else if(str[i] == '\\') {
			out_tmp[out_ptr++] = '\\';
			out_tmp[out_ptr++] = '\\';
		} else if(str[i] == '>') {
			out_tmp[out_ptr++] = '&';
			out_tmp[out_ptr++] = 'g';
			out_tmp[out_ptr++] = 't';
			out_tmp[out_ptr++] = ';';
		} else if(str[i] == '<') {
			out_tmp[out_ptr++] = '&';
			out_tmp[out_ptr++] = 'l';
			out_tmp[out_ptr++] = 't';
			out_tmp[out_ptr++] = ';';
		} else if(str[i] == '&') {
			out_tmp[out_ptr++] = '&';
			out_tmp[out_ptr++] = 'a';
			out_tmp[out_ptr++] = 'm';
			out_tmp[out_ptr++] = 'p';
			out_tmp[out_ptr++] = ';';
		} else if(str[i] == '\n') {
			out_tmp[out_ptr++] = '<';
			out_tmp[out_ptr++] = 'b';
			out_tmp[out_ptr++] = 'r';
			out_tmp[out_ptr++] = '/';
			out_tmp[out_ptr++] = '>';
		} else {
			out_tmp[out_ptr++] = str[i];
		}
	}
}

bool str_cmp(char* ptr, string str) {
	size_t len = str.length;
	for(size_t i = 0; i < len; i++) {
		if(*(ptr+i) != str[i]) {
			return false;
		}
	}
	
	return true;
}

struct dyn_connection {
	static uint allocated;
	static uint used;
	static uint connected;
	static uint reading;
	static uint writing;
	static uint user_connections;
	static dyn_connection* first;
	static dyn_connection* last;
	
	dyn_connection* next;
	dyn_connection* prev;
	
	string sid; //OPTIMIZE!! - convert this to char[26]
	Session session;
	int uid = -1;
	uint wid;
	
	uint socket;
	uint cur_stage;
	int timeout_time;
	int last_seen; // not used right now .. move to the buddy list server
	bool keepalive;
	int gzip;
	ubyte[4] ip;
	
	uint content_len;
	int header_len;
	string input;
	string doc;
	string orig_qs;
	string query_string;
	string func_name;
	int browser = -1;
	int browser_version;
	
	int cur_ptr;
	
	char* output;
	char* output_file;
	uint output_len;
	
	string[string] POST;
	string[string] FUNC;
	string[string] COOKIE;
	
	double begin_connect;
	double begin_reading;
	double end_reading;
	double begin_processing;
	double end_processing;
	double begin_writing;
	double end_writing;
	
	// always start with one connection... Perhaps later, we can have a config pre-allocate...
	static void init() {
		first = last = new dyn_connection;
		first.output = cast(char*)malloc(buffer_size);
		allocated++;
		
		for(int i = 1; i < 20; i++) {
			dyn_connection.connect();
		}
		
		used = 0;
	}
	
	static dyn_connection* connect() {
		dyn_connection* conn;
		// first iterate through all of the connections to see if there is a free one
		if(used < allocated) {
			conn = first;
			do {
				if(conn.socket == 0) {
					conn.input.length = 0;
					used++;
					assert(conn.output_file == null);
					return conn;
				}
				
				conn = conn.next;
			} while(conn);
		}
	
		// no free connections, so make a new one
		conn = new dyn_connection;
		conn.output = cast(char*)malloc(buffer_size);
		conn.prev = last;
		last.next = conn;
		last = conn;
		assert(last.next == null);
		assert(conn.output_file == null);
		allocated++;
		debug noticeln("allocate ++ (", allocated, ")");
		
		used++;
		return conn;
	}
	
	void end() {
		io_close(cur_sock);
		
		double now = microtime();
		double connect_time = (begin_reading - begin_connect) * 0.001;
		double reading_time = (end_reading - begin_reading) * 0.001;
		double processing_time = (end_processing - begin_processing) * 0.001;
		double writing_time = (now - begin_writing) * 0.001;
		double total_time = ((now - begin_connect) * 0.001);
		double waiting_time = total_time - reading_time - processing_time - writing_time;
		
		noticeln("+-------------");
		if(cur_stage == 1) {
			connected--;
		} else if(cur_stage == 2) {
			reading--;
		} else if(cur_stage == 3) {
			writing--;
		}
		
		printf("| connect time: %0.2fms\n", connect_time);
		printf("| reading time: %0.2fms\n", reading_time);
		printf("| processing time: %0.2fms\n", processing_time);
		printf("| writing time: %0.2fms\n", writing_time);
		//noticeln("+-------------");
		printf("| > total time: %0.2fms\n", total_time);
		printf("| > waiting time: %0.2fms\n", waiting_time);
		noticeln("+-------------");
		
		
		cur_stage = 0;
		socket = 0;
		uid = -1;
		browser = -1;
		content_len = 0;
		header_len = 0;
		cur_ptr = 0;
		gzip = 0;
		// no need for keepalive (set in process_header)
		input = null;
		sid = null;
		POST = null;
		FUNC = null;
		COOKIE = null;
		session = null;
		func_name = null;
		output_file = null;
		output_len = 0;
		used--;
	}
	
	void make_session() {
		if(this.sid.length == 26) {
			this.session = Session.get_session(this.sid);
			if(this.session is null) {
				this.session = new Session(0);
				this.session.put_sid(sid);
			}
		} else {
			assert(this.session is null);
			this.session = new Session(0);
			this.session.generate_sid();
			.sid = this.sid = cur_conn.sid = this.session.sid.dup;
			.cur_session = null; // this is to make sure that it will get set in print_cookie
		}
		
		if(!this.session.lang) {
			this.session.lang = PNL.default_idioma;
		}
	}
	
	/*
	static void destroy(connection* conn) {
		if(connection_first != connection_last) {
			if(connection_first == conn) {
				connection_first = conn.next;
			} else if(connection_last == conn) {
				connection_last = conn.prev;
			} else {
				conn.prev.next = conn.next;
				conn.next.prev = conn.prev;
			}
		} else {
			connection_first = connection_last = null;
		}
		
		delete conn; // need this?
	}
	*/
	
	// this needs lots of fixing up, because I will need to put it in a buddylist daemon of sorts
	/*static dyn_connection* find(uint uid, uint wid) {
		if(user_connections) {
			assert(last);
			assert(first);
			if(last.socket == 0 && last.uid == uid && last.wid == wid) {
				return last;
			}
			
			//stdoutln("match: uid ", uid, " wid ", wid);
			dyn_connection* conn = first;
			while(conn != last) {
				//stdoutln(" == uid ", conn.uid, " wid ", conn.wid);
				if(conn.socket == 0 && conn.uid == uid && conn.wid == wid) {
					return conn;
				}
				
				conn = conn.next;
			}
		}
		
		return null;
	}
	
	static void release(uint uid, string text) {
		user* ptr_user = uid in users;
		if(ptr_user) {
			uint c = ptr_user.connections;
			dyn_connection* conn = first;
			if(c && conn) {
				do {
					if(conn.uid == uid) {
						assert(0);
						//conn.output ~= text;
						if(conn.socket) {
							//stdoutln("uid ", uid, ": connection released");
							io_wantwrite(conn.socket);
							c--;
						}
					}
					
					conn = conn.next;
				} while(c && conn != last);
			}
		} else {
			// should never get here, but if I do, it will crash
		}
	}
	
	static uint release_connections(int older_than) {
		uint collected = user_connections;
		
		debug {
			foreach(uid, usr; users) {
				uint cn_us = 0;
				if(user_connections) {
					assert(last.next == null);
					dyn_connection* conn = first;
					do {
						if(conn.uid == uid) {
							cn_us++;
						}
						
						conn = conn.next;
					} while(conn);
				}
				
				assert(cn_us == usr.connections);
			}
		}
		
		if(user_connections) {
			assert(first);
			assert(last);
			dyn_connection* conn = first;
			do {
				if(conn.uid > 0 && conn.socket == 0 && conn.last_seen < older_than) {
					user* usr = conn.uid in users;
					assert(usr);
					usr.connections--;
					user_connections--;
					assert(usr.connections >= 0);
					if(usr.connections == 0) {
						auto ptr_user_won = conn.uid in user_won;
						if(ptr_user_won) {
							foreach(uint zid; *ptr_user_won) {
								release(zid, Integer.toString(conn.uid) ~ " is now offline");
							}
						}
					}
					
					conn.uid = 0;
					conn.wid = 0;
				}
				
				conn = conn.next;
			} while(conn);
		}
		
		return collected - user_connections;
	}*/
}

struct user {
	int last_seen;
	int connections; // == 0 -- disconnected, > 0 -- connected
	// logic is, if the client does not reconnect again within x seconds, the person is disconnected, and should notify his buddies;
	
	//uint[] buddies;
	//uint[] alerts; 
}

//TODO!! - move this out of this file... or rather, move all of the other stuff out of the core file. 
class Core {
	static:
	char[] js_out;
	
	uint recollect;
	uint out_offset;
	int uptime;
	
	
	int init() {
		out_tmp = cast(char*)malloc(buffer_size);
		uptime = cast(int)time(null);
		out_ptr = 0;
		
		GC.collect();
		GC.reserve(1024 * 1024 * 512);
		return 0;
	}
	
	char[] compress(char[] srcbuf, int level) {
		int err;
		char[] destbuf;
		size_t destlen;
		
		destlen = (srcbuf.length + ((srcbuf.length + 1023) / 1024) + 12);
		destbuf = new char[destlen];
		//std.gc.hasNoPointers(destbuf.ptr);
		err = compress2(cast(char*)destbuf.ptr, &destlen, cast(char*)srcbuf.ptr, cast(uint) srcbuf.length, level);
		if(err) {
			delete destbuf;
			throw new Exception("zlib error: " ~ Integer.toString(err));
		}
		
		destbuf.length = destlen;
		return destbuf;
	}
	
	uint begin_num_queries;
	double begin_query_time;
	
	void get_session() {
		Session session = null;
		string sid = cur_conn.sid;
		cur_conn.uid = 0;
		if(sid.length == 26) {
			session = Session.get_session(sid);
			if(!session) {
				assert(session is null);
				debug errorln("New Session...");
				cur_conn.make_session();
				session = cur_conn.session;
				assert(cur_conn.session);
				assert(session !is null && cur_conn.session == session || session is null);
			}
			
			debug errorln("sid: ", sid, " length: ", sid.length);
			debug errorln("session.uid ", session.uid);
			debug errorln("session.online ", session.online);
			debug errorln("session.expire_time ", session.expire_time);
			debug errorln("session.last_request ", session.last_request);
			debug errorln("request_time ", request_time);
			debug errorln("difference ", request_time - session.last_request);
			
			.cur_session = cur_conn.session = session;
			assert(.cur_session == cur_conn.session);
			session.hits++;
			session.d_last_request = request_time;
			
			if(session.uid > 0) {
				user_session = new UserSession(session.uid);
				
				//version(release) {
					if(session.last_request + session.expire_time > request_time && session.online) {
						user_session.hits++;
						session.hits++;
						session.last_request = request_time;
						.uid = cur_conn.uid = session.uid;
					} else {
						//if(true) {
							session.time_delta = session.last_request;
							
						/*} else {
							// log out
							.uid = 0;
							PANELS = null;
							PANELS["p1"] = "inactivepopup";
						}*/
					}
				/*} else {
					debug errorln("session.hits ", session.hits);
					session.last_request = request_time;
					.uid = cur_conn.uid = session.uid;
				}*/
				
				user_session.last_request = request_time;
				user_session.save();
			}
			
			assert(session.uid == .cur_session.uid);
			
			return;
		}
	}
	
	ulong request_num;
	void do_page_request() {
		request_num++;
		debug errorln("------------------------");
		debug errorln("request: ", request_num);
		debug errorln("------------------------");
		
		stats.hits++;
		
		if(func_name.length) {
			debug errorln("found outside func in post: ", func_name);
			int function()* f_func = func_name in PNL.public_funcs;
			if(f_func) {
				debug errorln("calling... ", func_name);
				int function() func = cast(int function())*(cast(int function()*)f_func);
				func_ret = func();
				debug errorln("returned: ", (func_ret == HACKING ? "HACKING" : (func_ret == FAILURE ? "FAILURE" : Integer.toString(func_ret))));
			} else {
				debug errorln("couldn't find function... ", func_name);
			}
		}
		
		version(notrelease) {
			if(settings.reload_panels) {
				PNL.reload_panels(settings.panels_dir, settings.lang_dir);
				load_files();
				//GC.collect(); // <-- this is horendously slow on llvm
			}
		}
		
		
		process_page();
		assert(cur_session !is null);
		assert(cur_session == cur_conn.session);
		
		debug noticeln("saving session...");
		debug noticeln("sid: ", sid);
		debug noticeln("cur_conn.session.uid: ", cur_conn.session.uid);
		debug noticeln("session.uid: ", cur_session.uid);
		debug noticeln("session.hits: ", cur_session.hits);
		debug noticeln("session.lang: ", cur_session.lang);
		debug noticeln("uid: ", uid);
		cur_session.save();
		if(uid) {
			user_session.save();
		}
		
		out_ptr = 0;
		sid = null;
	}
	
	void terminate() {
		//noticeln("main queries executed: ", PostgreCore.query_count);
		//noticeln("current number of connections: ", PostgreCore.num_connections);
		//PostgreCore.pg_disconnect_all();
	}
	
	void process_page() {
		// this is for debug
		//uid = 11;
		debug errorln("original query string: ", cur_conn.orig_qs);
		debug errorln("processed query string: ", cur_conn.query_string);
		string* val;
		if(uid) {
			val = "uid" in POST;
			if(val) {
				zid = toUint(*val);
				zid_set = 1;
			} else {
				zid = uid;
				zid_set = 0;
			}
			
			is_me = uid > 0 && zid == uid;
		}
		
		val = "xid" in POST;
		if(val) {
			xid = toUint(*val);
			xid_set = 1;
		} else {
			xid = 0;
			xid_set = 0;
		}
		
		val = "wid" in POST;
		if(val) {
			wid = toUint(*val);
		} else {
			wid = 0;
		}
		
		val = "sid" in POST;
		if(val) {
			sid = (*val).dup;
		}
		
		val = "z" in POST;
		if(val) {
			string z = *val;
			size_t param_start = 0;
			size_t cloc = find_c(z, ',');
			do {
				if(cloc == -1) {
					cloc = z.length;
				}
				
				string each = z[param_start .. cloc];
				size_t loc = find_c(each, ':');
				if(loc != -1) {
					PANELS[each[0 .. loc].dup] = each[loc+1 .. $].dup;
				}
				
				param_start = cloc + 2;
				cloc = find_c(z, ',', param_start);
			} while(cloc != -1);
		}
		
		size_t save_ptr;
		if(func_name.length) {
			debug errorln("found func in post: ", func_name);
			//debug errorln(FUNC);
			int function()* f_func = func_name in PNL.funcs;
			if(f_func) {
				debug errorln("calling... ", func_name);
				int function() func = cast(int function())*(cast(int function()*)f_func);
				func_ret = func();
				
				debug errorln("returned: ", (func_ret == HACKING ? "HACKING" : (func_ret == FAILURE ? "FAILURE" : Integer.toString(func_ret))));
				//prt("func_return('");
				//prt(func_name);
				//prt("'," ~ Integer.toString(func_ret) ~ ");");
			} else {
				debug errorln("function not found...");
				//TODO! - probably a hacker, and we should record this.
			}
			
			PNL* f_ret = func_name in PNL.func_ret_pnl;
			if(f_ret) {
				save_ptr = out_ptr;
				(*f_ret).render;
				js_out ~= out_tmp[save_ptr .. out_ptr].dup;
				out_ptr = save_ptr;
			}
		}
		
		val = "EVAL" in COOKIE;
		if(val) {
			js_out ~= *val;
		}
		
		val = "y" in POST;
		if(val) {
			if(!*val) {
				prt(`<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/2000/REC-xhtml1-20000126/DTD/xhtml1-strict.dtd">`
					`<?xml version="1.0" encoding="utf-8" ?>`
					`<html><head><meta http-equiv="Content-Type" content="application/xhtml+xml; charset=utf-8" /></head><body><div><!-- `);
			}
			
			save_ptr = out_ptr;
			struct out_panel {
				string div;
				string panel;
				string name;
				int mode;
			}
			
			out_panel[] out_panels;
			foreach(div, panel; PANELS) {
				if(div.length && panel.length) {
					PNL* ptr_panel = panel in PNL.pnl;
					
					if(ptr_panel) {
						.div = div;
						if(uid || ptr_panel.is_public) {
							ptr_panel.render();
						} else {
							if(PNL.pnl_auth) {
								PNL.pnl_auth.render();
							} else {
								prt("You need to add an authenticator panel");
							}
						}
						
						char[] processed_panel;
						size_t len = out_ptr - save_ptr;
						if(cast(long)len > 0) {
							out_panel p;
							p.div = div;
							p.name = ptr_panel.name;
							p.mode = ptr_panel.mode;
							
							if(p.mode != PNL.MODE_JS) {
								processed_panel.length = len*2;
								uint processed_ptr = 0;
								for(auto i = save_ptr; i < out_ptr; i++) {
									if(out_tmp[i] == '\\') {
										processed_panel[processed_ptr++] = '\\';
										processed_panel[processed_ptr++] = '\\';
									} else if(out_tmp[i] == '-' && out_tmp[i+1] == '-') {
										// this is only if you're returning your result in html comments
										processed_panel[processed_ptr++] = '-';
										processed_panel[processed_ptr++] = '\\';
									} else if(out_tmp[i] == '"') {
										processed_panel[processed_ptr++] = '\\';
										processed_panel[processed_ptr++] = '"';
									} else if(out_tmp[i] != '\t' && out_tmp[i] != '\r' && out_tmp[i] != '\n') {
										processed_panel[processed_ptr++] = out_tmp[i];
									}
								}
								
								p.panel = processed_panel[0 .. processed_ptr];
							} else {
								p.panel = out_tmp[save_ptr .. out_ptr];
							}
							
							out_panels ~= p;
							out_ptr = save_ptr;
							prt("kernel.change('");
							prt(div);
							prt("','");
							prt(panel);
							prt("');");
							save_ptr = out_ptr;
						}
					} else {
						debug errorln("DEBUG!!! - you are requesting a panel (", panel, ") which does not exist");
					}
				}
			}
			
			out_ptr = save_ptr;
			int pnl_cnt = 0;
			foreach(p; out_panels) {
				if(p.panel.length) {
					stats.pnl_hits++;
					switch(p.mode) {
					default:
					case PNL.MODE_REPLACE:
						prt("var j=$('");
						prt(p.div);
						prt(`');if(j){j.innerHTML="`);
						prt(p.panel);
						prt(`"}`);
						break;
						
					case PNL.MODE_APPEND:
						prt("var j=$('");
						prt(p.div);
						prt(`');if(j){var k=document.createElement('div');k.innerHTML="`);
						prt(p.panel);
						prt(`";j.appendChild(k)}`);
						break;
					
					case PNL.MODE_APPEND_NO_REPLACE:
						prt("var j=$('");
						prt(p.div);
						prt("');if(j&&!$('");
						prt(p.name);
						prt("')){var k=document.createElement('div');k.id='");
						prt(p.name);
						prt(`';k.innerHTML="`);
						prt(p.panel);
						prt(`";j.appendChild(k);}`);
						break;
						
					case PNL.MODE_JS:
						prt(p.panel);
						break;
					}
				}
			}
			
			if(pnl_cnt) {
				cur_session.page_hits++;
				stats.page_hits++;
			}
			
			if(title !is null) {
				prt(`document.title="`);
				prt_esc_html(title);
				prt(`";`);
			}
			
			prt(Core.js_out);
			
			prt("done_loading();");
			if(!*val) {
				prt(" --></div></body></html>");
			}
		} else {
			debug errorln("no y=");
			debug errorln("sid: ", sid);
			debug errorln("sid.length ", sid.length);
			debug errorln("uid: ", uid);
			// I used to redirect here, but now I do it in JS, so it is 100% compatible with normal websites
			/*
			if(cur_conn.orig_qs.length) { // this is a url string, I want it a hash string:
				prt_conn("HTTP/1.1 302 Found\r\nLocation: http://");
				prt_conn(site_url);
				if(site_port != "80") {
					prt_conn(":");
					prt_conn(site_port);
				}
				
				prt_conn("/#");
				prt_conn(cur_conn.query_string);
				print_cookie();
				prt_conn("\r\n\r\n");
				
				debug errorln("redirecting to: ", out_tmp[0 .. out_ptr]);
				return;
			} else {*/
				debug errorln("rendering main");
				
				PNL* panel = ("main" in PNL.pnl);
				if(panel) {
					panel.render();
				}
			//}
		}
		
		prt_conn("HTTP/1.1 200 OK");
		print_cookie();
		
		//prt("\r\nDate: ");
		//prt(std.date.toString(std.date.getUTCtime()));
		prt_conn("\r\nExpires: Fri, 26 Oct 1985 11:11:00 GMT"
			"\r\nContent-Type: text/html\r\nContent-Length: ");
		
		if(cur_conn.gzip) {
			string output;
			if(PNL.final_replacements.length) {
				output = out_tmp[0 .. out_ptr].dup;
				out_ptr = 0;
				size_t cur_offset = 0;
				foreach(r; PNL.final_replacements) {
					string var = *cast(string*)r.ptr;
					if(var.ptr) {
						prt(output[cur_offset .. r.offset]);
						prt(var);
						cur_offset = r.offset;
					}
				}
				
				prt(output[cur_offset .. $]);
			}
			
			output = cast(char[])compress(out_tmp[0 .. out_ptr], 9);
			
			prt_conn(output.length + 8);
			prt_conn("\r\nContent-Encoding: gzip\r\n\r\n"
				"\x1f\x8b\x08\x00\x00\x00\x00\x00");
			prt_conn(output);
		} else {
			prt_conn(out_ptr);
			prt_conn("\r\n\r\n");
			size_t cur_offset = 0;
			foreach(r; PNL.final_replacements) {
				string var = *cast(string*)r.ptr;
				if(var.ptr) {
					prt_conn(out_tmp[cur_offset .. r.offset]);
					prt_conn(var);
					cur_offset = r.offset;
				}
			}
			
			prt_conn(out_tmp[cur_offset .. out_ptr]);
		}
		
		PNL.final_replacements.length = 0;
	}
	
	void print_cookie() {
		if("GET" in COOKIE) {
			prt_conn("\r\nSet-Cookie: GET=; expires=Sun, 27-May-2007 23:21:12 GMT");
		}
		
		cur_conn.make_session();
		cur_conn.session.uid = .uid;
		cur_session = cur_conn.session;
		
		if(!("SID" in COOKIE)) {
			debug noticeln("setting cookie to ", sid);
			//TODO!!! - add the domain to this cookie
			prt_conn("\r\nSet-Cookie: SID=");
			prt_conn(sid);
			prt_conn("; path=/; expires=Wed, 28 Dec 2011 11:11:00 GMT");
		}
		
		assert(cur_session !is null);
		assert(cur_conn.session !is null);
		assert(cur_session == cur_conn.session);
	}
}

/*

at the end of each connection, I can go through the lists cached in ram, and I can requests the versions, and expire
the lists where the version has changed.

*/

/*bool do_dynamic() {
	bool error = true;
	//string key_session = "SESSION:" ~ sid;
	//memcache_req* req = mc_req_new();
	//memcache_res* res = mc_req_add(req, key_session.ptr, key_session.length);
	//mc_get(session_mc, req);
	session = Session.get_session(sid);
	
	if(session) {
		uint uid = session.uid;
		
		if(session.online) {
			user* usr = uid in users;
			if(!usr) {
				user u;
				users[uid] = u;
				usr = uid in users;
				assert(usr.connections == 0);
				assert((uid in users) == usr);
			}
			
			cur_conn = dyn_connection.find(uid, wid);
			
			if(!cur_conn) {
				cur_conn = dyn_connection.connect();
				cur_conn.uid = uid;
				cur_conn.wid = wid;
				usr.connections++;
				dyn_connection.user_connections++;
			}
			
			assert(cur_conn.socket == 0);
			io_setcookie(cur_sock, cur_conn);
			cur_conn.socket = cur_sock;
			
			usr.last_seen = request_time;
			if(cur_conn.last_seen + SECONDS_TO_RECONNECT >= request_time) {
				// person is already logged in .. no online notifications
				io_nonblock(cur_sock);
				io_fd(cur_sock);
				io_dontwantwrite(cur_sock);
				//TODO!! I think reads time out, so I may way to do instead hold the connection in write mode
			} else if(!cur_conn.output_len) {
				io_dontwantread(cur_sock);
				io_wantwrite(cur_sock);
				
				//TODO!!!! - get buddy list from DB (or a buddy list server)
				// for now, we will pretend that the buddy list is: 11, 17, 18
				uint[] buddies;
				if(uid == 11) {
					buddies = [17, 18];
				} else if(uid == 17) {
					buddies = [11, 18];
				} else if(uid == 18) {
					buddies = [11, 17];
				}
				
				foreach(uint zid; buddies) {
					auto ptr_user_won = zid in user_won;
					if(ptr_user_won) {
						bool found_uid = false;
						foreach(xid; *ptr_user_won) {
							if(uid == xid) {
								found_uid = true;
								break;
							}
						}
						
						if(!found_uid) {
							//OPTIMIZE - length = length + 1, [$-1] = uid
							*ptr_user_won ~= uid;
						}
					} else {
						user_won[zid] ~= uid;
					}
					
					user* bud = zid in users;
					if(bud && bud.connections) {
						assert(0);
						//cur_conn.output ~= Integer.toString(zid) ~ " is online!";
					} else {
						assert(0);
						//cur_conn.output ~= Integer.toString(zid) ~ " is offline...";
					}
				}
				
				auto ptr_user_won = uid in user_won;
				if(ptr_user_won) {
					//stdoutln("uid ", uid, ": won is: ", user_won[uid]);
					foreach(uint zid; *ptr_user_won) {
						dyn_connection.release(zid, Integer.toString(uid) ~ " is now online");
					}
				}
				
				//stdoutln("uid ", uid, ": output: ", cur_conn.output);
			}
			
			
			
			cur_conn.last_seen = request_time;
		} else {
			//TODO!!! - give this a proper javascript error
			// this is a rare case, so I'll deal with the performance hit
			io_wantwrite(cur_sock);
			cur_conn = dyn_connection.connect();
			cur_conn.socket = cur_sock;
			assert(0);
			//cur_conn.output ~= "error you have been disconnected.. relogin.";
		}
		
		error = false;
	}
	
	return error;
}*/

void process_cookie(string qs) {
	//TODO!!!! - write unittests for this function
	//OPTIMIZE! - surely this can be done faster... cleanse_url_string is slow.
	size_t len = qs.length;
	size_t eq = 0;
	size_t last_amp = 0;
	size_t i = 0;
	while(i < len) {
		if(eq == 0 && qs[i] == '=') {
			eq = i;
		}
		
		if((qs[i] == ' ' && qs[i-1] == ';') || i+1 == len) {
			if(i+1 == len) {
				i+=2;
			}
			
			string key;
			if(eq > last_amp) {
				key = qs[last_amp .. eq++];
			}
			
			string value;
			if(eq > last_amp) {
				value = cleanse_url_string(qs[eq .. i-1]);
				cur_conn.COOKIE[key] = value;
				if(key == "SID") {
					cur_conn.sid = value;
				} else if(key == "L") {
					cur_session.lang = value;
				} else if(key == "GET") {
					process_qs(value.dup);
				}
			}
			
			assert(i >= len || (qs[i] == ' ' && qs[i-1] == ';'));
			last_amp = i+1;  // plus 1, because it is the start of the string afte the amp
			eq = 0;
		}
		
		i++;
	}
}


unittest {
	UNIT("dyn_connection #1", () {
		cur_conn = new dyn_connection;
		process_qs("f_mmm=1111&lala=1234&5=4&&y=");
		assert("mmm" in cur_conn.FUNC);
		assert(cur_conn.FUNC["mmm"] == "1111");
		assert("lala" in cur_conn.POST);
		assert(cur_conn.POST["lala"] == "1234");
		assert("5" in cur_conn.POST);
		assert(cur_conn.POST["5"] == "4");
		assert("y" in cur_conn.POST);
		assert(cur_conn.POST["y"] == "");
	});
	
	UNIT("dyn_connection #2", () {
		cur_conn = new dyn_connection;
		process_qs("f=myfunc&z=j:home");
		assert(cur_conn.func_name != "myfunc");
		assert("z" in cur_conn.POST);
		assert(cur_conn.POST["z"] == "j:home");
	});
	
	UNIT("dyn_connection #3", () {
		cur_conn = new dyn_connection;
		process_cookie("SID=123456789012345678901234566; GET=lala=1234&z=&mm=");
		assert("SID" in cur_conn.COOKIE);
		assert(cur_conn.COOKIE["SID"] == "123456789012345678901234566");
		assert("GET" in cur_conn.COOKIE);
		assert(cur_conn.COOKIE["GET"] == "lala=1234&z=&mm=");
	});
}

void process_qs(string qs) {
	//OPTIMIZE! - surely this can be done faster... cleanse_url_string is slow.
	string query_string = cur_conn.query_string;
	size_t len = qs.length;
	size_t eq = 0;
	size_t last_amp = 0;
	size_t i = 0;
	while(i < len) {
		if(qs[i] == '=') {
			eq = i;
		}
		
		if(qs[i] == '&' || i+1 == len) {
			if(i+1 == len) {
				i++;
			}
			
			string key;
			if(eq > last_amp) {
				key = qs[last_amp .. eq++];
			}
			
			string value;
			if(eq > last_amp) {
				value = cleanse_url_string(qs[eq .. i]);
			
				// do stuff
				if(key.length > 2 && key[0] == 'f' && key[1] == '_') {
					cur_conn.FUNC[key[2 .. $]] = value;
				} else {
					cur_conn.POST[key] = value;
					if(key.length == 1 && key[0] == 'f' && cur_conn.content_len > 0) {
						cur_conn.func_name = value;
					} else if(key == "L") {
						cur_session.lang = value;
					} else if(key != "y" && key != "wid") {
						if(query_string.length == 0) {
							query_string = qs[last_amp .. i];
						} else {
							query_string ~= qs[last_amp-1 .. i];
						}
					}
				}
			}
			
			assert(i == len || qs[i] == '&');
			last_amp = i+1;  // plus 1, because it is the start of the string afte the amp
		}
		
		i++;
	}
	
	cur_conn.orig_qs = qs;
	cur_conn.query_string = query_string;
}

void process_post() {
	debug noticeln("PROCESS POST");
	// this function referenences data already in the buffer, because process_post always happens in the same pass as the request processing.
	string post = cur_conn.input[cur_conn.header_len .. $];
	assert(post[0] != '\r');
	assert(post[0] != '\n');
	bool not_boundary = false;
	size_t i, j, k;
	
	for(i = 0; i < post.length; i++) {
		if(post[i] == '=') {
			not_boundary = true;
			break;
		} else if(post[i] == '\r') {
			break;
		}
	}
	
	if(not_boundary) {
		string qs = post;
		string query_string = cur_conn.query_string;
		size_t len = qs.length;
		size_t eq = 0;
		size_t last_amp = 0;
		while(i < len) {
			if(qs[i] == '=') {
				eq = i;
			}
			
			if(qs[i] == '&' || i+1 == len) {
				if(i+1 == len) {
					i++;
				}
				
				string key;
				if(eq > last_amp) {
					key = qs[last_amp .. eq++];
				}
				
				string value;
				if(eq > last_amp) {
					value = cleanse_url_string(qs[eq .. i]);
				
					// do stuff
					if(key.length > 2 && key[0] == 'f' && key[1] == '_') {
						FUNC[key[2 .. $]] = value;
					} else {
						POST[key] = value;
						if(key.length == 1 && key[0] == 'f') {
							func_name = value;
						} else if(key != "y" && key != "wid") {
							if(query_string.length == 0) {
								query_string = qs[last_amp .. i];
							} else {
								query_string ~= qs[last_amp-1 .. i];
							}
						}
					}
				}
				
				
				
				//assert(qs[i] == '&' || i == len);
				last_amp = i+1;  // plus 1, because it is the start of the string afte the amp
			}
			
			i++;
		}
		
		cur_conn.query_string = query_string;
		
	} else {
		// this is multipart form data
		
		// set the end of the line to 0 (for safety's sake)
		//post[i+1] = '\0';
		string boundary = post[0 .. i+1];
		string disposition = null;
		string type = null;
		
		size_t endl = 0;
		size_t l = post.length;
		for(k = i; k < l; k++) {
			if(post[k] >= 'A' && post[k] <= 'Z') {
				if(endl < k) {
					for(size_t t = k; t < l; t++) {
						if(post[t] == '\r' && post[t+1] == '\n') {
							endl = t;
							break;
						}
					}
				}
				
				if(disposition == null) {
					if(str_cmp(&post[k], "Content-Disposition: ")) {
						j = k + "Content-Disposition: ".length;
						disposition = trim(post[j .. endl]);
					}
				}
				
				if(type == null) {
					if(str_cmp(&post[k], "Content-Type: ")) {
						j = k + "Content-Type: ".length;
						type = trim(post[j .. endl]);
					}
				}
				
				if(post[endl+2] == '\r' && post[endl+3] == '\n') {
					string data;
					i = find_s(post, boundary, k);
					if(i != -1) {
						data = post[endl+4 .. ++i];
						k = i + boundary.length;
					} else {
						data = post[endl+4 .. $];
						k = post.length;
					}
					
					size_t name_loc = find_s(disposition, `name="`);
					size_t end_name_loc;
					if(name_loc != -1) {
						name_loc += `name="`.length;
						end_name_loc = find_c(disposition, '"', name_loc);
					}
					
					if(name_loc != -1 && end_name_loc != -1) {
						string name = disposition[name_loc .. end_name_loc];
						if(name.length > 2 && name[1] == '_' && name[0] == 'f') {
							FUNC[name[2 .. $]] = data;
							
							size_t filename_loc = find_s(disposition, `filename="`);
							if(filename_loc != -1) {
								filename_loc += `filename="`.length;
								assert(disposition[filename_loc] != '"');
								size_t end_filename_loc = find_c(disposition, '"', filename_loc);
								if(end_filename_loc != -1) {
									FUNC[name[2 .. $] ~ "_filename"] = disposition[filename_loc .. end_filename_loc];
									POST[name[2 .. $] ~ "_type"] = type;
								}
							}
						} else {
							if(name == "f") {
								func_name = data;
							} else {
								POST[name] = data;
								if(name != "y" && name != "wid") {
									string query_string = cur_conn.query_string;
									if(query_string.length == 0) {
										query_string = name ~ '=' ~ data;
									} else {
										query_string ~= '&' ~ name ~ '=' ~ data;
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

int process_header() {
	size_t j, k, l;
	bool keepalive;
	uint wid;
	string req_header = cur_conn.input;
	l = cast(uint)req_header.length;
	cur_conn.query_string = "";
	
	if(req_header[0] == 'G') {
		// GET /lala?yeah=true HTTP/1.1
		// |---^
		j = k = 4;
		cur_conn.content_len = 0;
	} else if(req_header[0] == 'P') {
		// POST /lala?yeah=true HTTP/1.1
		// |----^
		j = k = 5;
		cur_conn.content_len = -1;
	} else {
		prt_conn("HTTP/1.1 500 Internal Server Error\r\n");
		debug errorln("500 error:\n", req_header);
		return -1;
	}
	
	assert(req_header[k] != ' ');
	assert(req_header[k] == '/');
	for(; k < l; k++) {
		if(req_header[k] == ' ') {
			string uri = req_header[j .. k];
			auto len = find_c(uri, '?');
			if(len != -1) {
				cur_conn.doc = uri[0 .. len];
				process_qs(uri[++len .. $]);
			} else {
				cur_conn.doc = uri;
				cur_conn.orig_qs.length = 0;
			}
			
			//GET /lala?yeah=true HTTP/1.0
			//                   |-------^
			k += 8;
			keepalive = (req_header[k] == '0' ? false : true); // HTTP/1.0 doesn't support keepalive
			
			k++;
			if(req_header[k] == '\r' && req_header[k+1] == '\n') { 
				k += 2;
				break;
			} else {
				prt_conn("HTTP/1.1 500 Internal Server Error\r\n");
				debug errorln("500 error:\n", req_header);
				return -1;
			}
		}
	}
	
	size_t endl = 0;
	for(; k < l; k++) {
		if(req_header[k] >= 'A' && req_header[k] <= 'Z') {
			if(endl < k) {
				for(size_t t = k; t < l; t++) {
					if(req_header[t] == '\r' && req_header[t+1] == '\n') {
						endl = t;
						break;
					}
				}
			}
			
			if(cur_conn.content_len == -1) {
				if(str_cmp(&req_header[k], "Content-Length: ")) {
					j = k + "Content-Length: ".length;
					cur_conn.content_len = toUint(req_header[j .. endl]);
				}
			}
			
			if(cur_conn.browser == -1) {
				if(str_cmp(&req_header[k], "User-Agent: ")) {
					j = k + "User-Agent: ".length;
					string agent = tango.text.Ascii.toLower(req_header[j .. endl]);
					size_t loc = find_s(agent, "msie");
					if(loc != -1) {
						cur_conn.browser = BROWSER.MSIE;
						if(agent.length > loc+6) {
							char ver = agent[loc+6];
							if(ver == '6') {
								cur_conn.browser_version = 6;
							} else if(ver == '7') {
								cur_conn.browser_version = 7;
							} else {
								cur_conn.browser_version = -1;
							}
						}
					} else if(find_s(agent, "gecko") != -1) {
						cur_conn.browser = BROWSER.MOZILLA;
						//TODO!!! - add the version number check
					} else if(find_s(agent, "opera") != -1) {
						cur_conn.browser = BROWSER.OPERA;
						//TODO!!! - add the version number check
					} else if(find_s(agent, "safari") != -1) {
						cur_conn.browser = BROWSER.SAFARI;
						//TODO!!! - add the version number check
					} else if(find_s(agent, "validator") != -1) {
						cur_conn.browser = BROWSER.VALIDATOR;
					} else {
						cur_conn.browser = BROWSER.OTHER;
					}
				}
			}

			// There is NOTHING that I serve that ever checks modification time. We always change file names...
			if(str_cmp(&req_header[k], "If-Modified-Since: ")) {
				debug noticeln("found if modified...!!!!");
				prt_conn("HTTP/1.1 304 Not Modified\r\n");
				return -1;
			}
			
			if(str_cmp(&req_header[k], "Accept-Encoding: ")) {
				j = k + "Accept-Encoding: ".length;
				if(find_s(req_header[j .. endl], "gzip") != -1) {
					cur_conn.gzip = true;
				} else {
					cur_conn.gzip = false;
				}
			}
			
			if(keepalive && str_cmp(&req_header[k], "Connection: ")) {
				j = k + "Connection: ".length;
				if(cur_conn.keepalive == false && str_cmp(&req_header[j], "keep-alive")) {
					cur_conn.keepalive = true;
				} else if(str_cmp(&req_header[j], "close")) {
					cur_conn.keepalive = false;
				}
			}
			
			if(keepalive && str_cmp(&req_header[k], "Keep-Alive: ")) {
				j = k + "Keep-Alive: ".length;
				uint keepalive_time = toUint(req_header[j .. endl]);
				//TODO!! - set the keepalive timeout
			}
			
			if(str_cmp(&req_header[k], "Cookie: ")) {
				j = k + "Cookie: ".length;
				debug noticeln("Cookie: ", req_header[j .. endl]);
				process_cookie(req_header[j .. endl]);
			}
			
			if(req_header[endl+2] == '\r' && req_header[endl+3] == '\n') {
				if(cur_conn.content_len == -1) {
					debug errorln("411 Length Required:\n", req_header);
					prt_conn("HTTP/1.0 411 Length Required\r\n");
					return -1;
				}
				
				Core.get_session();
				return cast(int)endl+4;
			}
		}
	}
	
	return 0;
}

int main_loop() {
	//GC.minimize();
	
	ubyte[16] ip_incoming;
	auto s = socket_tcp4();
	socket_bind4_reuse(s, settings.bind_ip.ptr, settings.bind_port);
	
	// LISTEN
	auto sock_listen = socket_listen(s, 16);
	if(sock_listen == -1) {
		errorln("could not listen");
		return 111;
	}
	
	//io_nonblock(s);
	if(!io_fd(s)) {
		errorln("could not get a file descriptor");
		return 112;
	}
	
	io_wantread(s);
	
	debug {
		noticeln("accepting connections on ", cast(char)settings.bind_ip[0], ".", cast(char)settings.bind_ip[1], ".", cast(char)settings.bind_ip[2], ".", cast(char)settings.bind_ip[3], ":", cast(int)settings.bind_port, " ...");
	} else {
		noticeln("accepting connections...");
	}
	
	// END LISTEN
	
	
	// main loop
	char[4096] req_data;
	while(true) {
		// wait up to one second and loop again to do garbage collection / maintenance
		io_waituntil2(1000);
	
		//GC.disable();
		bool do_gc = true;
		double begin_loop = microtime();
		double now = begin_loop;
		request_time = cast(int)time(null);
		
		// can write
		int writes = 0;
		while(++writes <= 50 && (cur_sock = cast(uint)io_canwrite()) != -1) {
			double begin_write = microtime();
			
			do_gc = false;
			dyn_connection* conn = cast(dyn_connection*)io_getcookie(cur_sock);
			
			if(conn) {
				if(cur_conn.cur_stage == 2) {
					cur_conn.cur_stage = 3;
					conn.begin_writing = microtime();
					dyn_connection.reading--;
					dyn_connection.writing++;
				}
				
				assert(conn.socket == cur_sock);
				ulong how_much = conn.output_len - conn.cur_ptr;
				ulong ideal = how_much;
				if(ideal > 8000) {
					ideal = 8000;
				} else if(ideal < 4000 && ideal <= how_much) {
					ideal = 4000;
				}
				
				if(how_much > ideal) {
					how_much = ideal;
				}
				
				void* output;
				if(conn.output_file == null) {
					output = conn.output;
				} else {
					output = conn.output_file;
				}
				
				auto l = io_trywritetimeout(cur_sock, cast(char*)output + conn.cur_ptr, how_much);
				
				if(l+conn.cur_ptr == conn.output_len) {
					debug noticeln("connection success ", cur_sock);
					//conn.output.length = 0;
					if(conn.keepalive) {
						//io_dontwantwrite(i);
						//io_wantread(i);
						//TODO!! - use keepalive properly
						conn.end();
					} else {
						//io_dontwantwrite(i);
						conn.end();
					}
				} else if(l == -3) {
					conn.end();
				} else if(l > 0) {
					conn.cur_ptr += l;
				}
			} else {
				//io_dontwantwrite(i);
				io_close(cur_sock);
			}
			
			now = microtime();
			printf("writing time: %0.2fms\n", (now - begin_write) * 0.001);
		}
		
		int reads = 0;
		while(++reads <= 5 && (cur_sock = cast(uint)io_canread()) != -1) {
			do_gc = false;
			
			if(cur_sock == s) {
				double begin_connect = microtime();
				// new connection. put it in a different socket
				int n;
				uint connects = 10 + dyn_connection.reading + dyn_connection.writing - dyn_connection.connected;
				// && dyn_connection.connected <= dyn_connection.reading + 10
				while(dyn_connection.used <= MAX_CONNECTIONS && --connects && (n = socket_accept4(s, cast(char*)ip_incoming.ptr, &settings.bind_port)) != -1) {
					cur_sock = n;
					//io_nonblock(n);
					if(io_fd(n)) {
						cur_conn = dyn_connection.connect();
						cur_conn.begin_connect = begin_connect;
						dyn_connection.connected++;
						cur_conn.socket = n;
						cur_conn.cur_stage = 1;
						cur_conn.ip[0 .. 4] = cast(ubyte[])ip_incoming[0 .. 4];
						io_wantread(n);
						io_setcookie(n, cur_conn);
					} else {
						errorln("io failed");
					}
				}
				
				now = microtime();
				printf("connecting time: %0.2fms\n", (now - begin_connect) * 0.001);
			} else {
				double begin_read = microtime();
				bool error = false;
				auto l = io_tryread(cur_sock, &req_data[0], 4096);
				
				if(l > 0) {
					cur_conn = cast(dyn_connection*)io_getcookie(cur_sock);
					if(cur_conn.cur_stage == 1) {
						cur_conn.cur_stage = 2;
						cur_conn.begin_reading = begin_read;
						dyn_connection.connected--;
						dyn_connection.reading++;
					}
					
					cur_conn.input ~= req_data[0 .. l];
					if(cur_conn.output_file == null && cur_conn.input.length > 4) {
						cur_conn.header_len = process_header();
						
						if(cur_conn.header_len == -1) { // header needs to write immediately..
							io_wantwrite(cur_conn.socket);
							break;
						}
					}
					
					if(cur_conn.header_len > 0) {
						cur_conn.end_reading = cur_conn.begin_processing = microtime();
						debug noticeln("doc: '", cur_conn.doc, "' ", cur_conn.socket, " qs: '", cur_conn.orig_qs, "'");
						if(cur_conn.orig_qs.length > 0 || cur_conn.doc[$-1] == '/') {
							if(cur_conn.content_len && cur_conn.content_len + cur_conn.header_len != cur_conn.input.length) {
								// this prevents trying to render the page, if there is a POST, and it's not fully downloaded yet
								debug noticeln("breaking ", cur_conn.content_len + cur_conn.header_len, " ", cur_conn.input.length, "\n\n");
								continue;
							}
							
							
							// the reason why all of this goes above, is because process_post will write directly to the global, not the connection structure
							.uid = cur_conn.uid;
							.sid = cur_conn.sid.dup;
							.wid = cur_conn.wid;
							.POST = cur_conn.POST;
							.FUNC = cur_conn.FUNC;
							.COOKIE = cur_conn.COOKIE;
							.func_name = cur_conn.func_name;
							.browser_type = cur_conn.browser;
							.browser_version = cur_conn.browser_version;
							.ip4 = *cast(uint*)(&cur_conn.ip[0]);
							debug noticeln("IP: ", ip4);
							
							if(cur_conn.content_len) {
								process_post();
							}
							
							if(cur_conn.doc == "/d/" && wid) {
								errorln("TODO!! - add the dynamic back");
								//do_dynamic();
							} else {
								Core.do_page_request();
								io_wantwrite(cur_conn.socket);
							}
						} else {
							string doc = cur_conn.doc[1 .. $];
							
							void** file_ptr;
							if(cur_conn.gzip) {
								file_ptr = doc in FILES_GZIP;
							} else {
								file_ptr = doc in FILES;
							}
							
							if(file_ptr) {
								cur_conn.output_file = ((cast(char*)(*file_ptr)) +4);
								cur_conn.output_len = *cast(uint*)(*file_ptr);
							} else {
								
								//TODO!! - change this to AIO in the C library, cuse this is slow.
								//OPTIMIZE!! - perhaps I can remember the biggest size file, then serve that size, instead of duplicating the thumbs
								//OPTIMIZE!! - I have found that 1 in about 7 files really benefits from gzip encoding... if it does benefit, then I can
								if(doc.length > 2 && doc[0] == 'j' && doc[1] == '/') {
									string photo = doc[2 .. $];
									//TODO!!!! temporary, so my computer doesn't suck... delete me!
									if(find_c(photo, '/') != -1) {
										goto error;
									}
									// j/[size][hash]
									
									int exists;
									string real_file;
									int photo_type;
									if(photo.length > 7) {
										real_file = get_real_filename(photo);
										photo_type = get_photo_type(photo);
										//exists = std.file.exists(real_file);
										exists = Path.exists(real_file);
										if(!exists && doc.length > 9) {
											exists = process_photo(photo);
										}
									} else if(photo[0] == 'n' && photo[1] == 'f') {
										real_file = "/j/" ~ photo;
										photo_type = PHOTO_INFO.JPG;
										exists = Path.exists(real_file);
										if(!exists) {
											exists = process_nf(photo);
										}
									}
									
									if(exists) {
										string data = cast(char[])File.get(real_file);
										string type;
										type.length = 20;
										switch(photo_type) {
										case PHOTO_INFO.JPG:
											type = "image/jpeg";
											break;
										
										case PHOTO_INFO.GIF:
											type = "image/gif";
											break;
										
										case PHOTO_INFO.PNG:
											type = "image/png";
											break;
										
										default:
											goto error;
										}
										
										int file_len = cast(int)data.length;
										data = "\x1f\x8b\x08\x00\x00\x00\x00\x00" ~ cast(char[])Core.compress(data, 9);
										debug printf("compressed from %d to %d (%0.1f%% of orig size)\n", file_len, data.length, (cast(float)data.length / file_len)*100);
										prt_conn("HTTP/1.1 200 OK"
										"\r\nContent-Encoding: gzip"
										"\r\nExpires: Wed, 28 Dec 2011 11:11:00 GMT"
										"\r\nContent-Type: " ~ type ~
										//"\r\nLast-Modified: Fri, 26 Oct 1985 11:11:00 GMT"
										"\r\nContent-Length: " ~ Integer.toString(file_len) ~
										"\r\n\r\n" ~ data);
									}
								} else {
									prt_conn("HTTP/1.1 404 OK"
										"\r\nContent-Type: text/html"
										"\r\n\r\n"
										"<h2>not found</h2>");
								}
							}
							
							io_wantwrite(cur_conn.socket);
						}
						
						//TODO!! save session here, so I can track how many files were downloaded for each user as well...
						//that would help me to see if someone is scripting the site or not, because someone who is not downloading a single file in a short period of time = a script
						
						cur_conn.end_processing = microtime();
					}
				} else if(l == -3) {
					goto error;
				}
				
				
				
				
				if(error) {
error:				cur_conn = cast(dyn_connection*)io_getcookie(cur_sock);
					io_close(cur_sock);
					errorln("closed with error");
					if(cur_conn) {
						cur_conn.end();
					}
				}
				
				now = microtime();
				printf("reading/processing time: %0.2fms\n", (now - begin_read) * 0.001);
			}
		}
		
		// CONNECTION IS CLOSED, NOW CLEAN UP:
		//GC.enable();
		
		// reset globals
		PANELS = null;
		Core.js_out = null;
		func_name = null;
		title = null;
		func_ret = 0;
		zid = is_me = 0;
		
		stats.since_gc++;
		
		// next, if the timestamp is different, then I know to start garbage collecting connections and the memory
		if(last_request_time != request_time) {
			last_request_time = request_time;
			
			if(dyn_connection.connected - dyn_connection.reading - dyn_connection.writing > 0) {
				uint d;
				while((d = io_timeouted()) != -1) {
					io_close(d);
				}
			}
			
			//uint collected = dyn_connection.release_connections(request_time - SECONDS_TO_RECONNECT);
			//debug noticeln("collected ", collected, " connections..");
			
			// output in a big block to the log file...
			
			
		}
		
		if(dyn_connection.connected || dyn_connection.reading || dyn_connection.writing) {
			do_gc = false;
		}
		
		if(do_gc || stats.since_gc > 500) {
			//if(stats.since_gc > 5) {
			//noticeln("FULL COLLECT ", stats.since_gc);
			stats.since_gc = 0;
			GC.collect();
			//}
		}
		
		if(!do_gc) {
			printf(" >> loop time: %0.2fms (%d/%d/%d) connected/reading/writing\n--------------\n", (now - begin_loop) * 0.001, dyn_connection.connected, dyn_connection.reading, dyn_connection.writing);
		}
	}
	
	io_close(s);
	return 0;
}

void serve_dir(string location, string prefix) {
	if(location[$-1] != '/') {
		location ~= '/';
	}
	
	if(prefix[$-1] != '/') {
		prefix ~= '/';
	}
	
	bool serve_dir_helper(FilePath fp) {
		string file = fp.toString();
		string f_orig = file;
		auto off = find_c(file, '/');
		while(off != -1) {
			file = file[++off .. $];
			off = find_c(file, '/');
		}
		
		string tmp = f_orig[location.length .. $];
		string data = cast(string)File.get(f_orig);
		serve_file(f_orig, prefix ~ tmp[0 .. $-file.length], data, null);
		return true;
	}
	
	scan_dir(FilePath(location), &serve_dir_helper);
}

void serve_file(string filename, string prefix, string data, string type) {
	int file_len = cast(int)data.length;
	if(file_len == 0) {
		debug noticeln("file '", filename, "' is empty. ignoring");
		return;
	}
	
	string file = filename;
	auto off = find_c(filename, '/');
	while(off != -1) {
		file = filename[++off .. $];
		off = find_c(filename, '/', off);
	}
	
	file = prefix ~ file;
	noticeln("preparing file: ", file);
	
	bool is_text = false;
	string output;
	if(type.length == 0) {
		type.length = 20;
		char[4] ext = filename[$-4 .. $];
		if(ext[1] == '.') {
			ext[0] = ' ';
		}
		
		switch(ext) {
		case ".css":
			type = "text/css";
			break;
			
		case " .js":
			type = "text/javascript";
			break;
			
		case "jpeg":
		case ".jpg":
			type = "image/jpeg";
			break;
		
		case ".gif":
			type = "image/gif";
			break;
		
		case ".png":
			type = "image/png";
			break;
		
		case ".ico":
			type = "image/x-icon";
			break;
		
		case ".swf":
			type = "application/x-shockwave-flash";
			break;
		
		case ".pdf":
			type = "application/pdf";
			break;
		
		case ".mp3":
			type = "audio/mpeg";
			break;
		
		case ".m3u":
			type = "audio/x-mpegurl";
			break;
		
		case ".dtd":
		case ".xml":
			type = "text/xml";
			break;
		
			
		default:
			type = "text/html";
		}
	}
	
	if(type[0 .. 4] == "text") {
		is_text = true;
	}
	
	if(settings.optimize_resources) {
		switch(type) {
		case "text/css":
			auto orig_len = data.length;
			data = css_optimizer(data);
			printf("obfuscated from %d to %d (%0.1f of orig size)\n", orig_len, data.length, (cast(float)data.length / orig_len)*100);
			break;
			
		case "text/javascript":
			auto orig_len = data.length;
			data = js_optimizer(data);
			printf("obfuscated from %d to %d (%0.1f of orig size)\n", orig_len, data.length, (cast(float)data.length / orig_len)*100);
			break;
		}
	}
	
	
	uint* ptr;
	string tmp = "HTTP/1.1 200 OK"
	"\r\nExpires: Wed, 28 Dec 2011 11:11:00 GMT"
	"\r\nContent-Type: " ~ type ~
	"\r\nContent-Length: " ~ Integer.toString(file_len) ~
	"\r\n\r\n" ~ data;
	
	ptr = cast(uint*)malloc(tmp.length+4);
	*ptr = cast(uint)tmp.length;
	FILES[file] = ptr;
	memcpy((cast(void*)ptr) + 4, tmp.ptr, tmp.length);
	
	//std.gc.hasNoPointers(&FILES);
	
	if(is_text && data.length > 100) {
		int data_len = cast(int)data.length;
		data = "\x1f\x8b\x08\x00\x00\x00\x00\x00" ~ cast(char[])Core.compress(trim(data), 9);
		printf("compressed from %d to %d (%0.1f%% of orig size)\n", data_len, data.length, (cast(float)data.length / file_len)*100);
		file_len = cast(int)data.length;
		
		//FILES_GZIP[file]
		tmp = "HTTP/1.1 200 OK"
		"\r\nExpires: Wed, 28 Dec 2011 11:11:00 GMT"
		"\r\nContent-Encoding: gzip"
		"\r\nContent-Type: " ~ type ~
		"\r\nContent-Length: " ~ Integer.toString(file_len) ~
		"\r\n\r\n" ~ data;
		
		ptr = cast(uint*)malloc(tmp.length+4);
		*ptr = cast(uint)tmp.length;
		memcpy((cast(void*)ptr) + 4, tmp.ptr, tmp.length);
	}
	
	FILES_GZIP[file] = ptr;
	
	//std.gc.hasNoPointers(&FILES_GZIP);
}

void parse_config(string config_file) {
	debug noticeln("-- parsing config");
	string* val;
	config_file = cast(string)File.get(config_file);
	config_file = replace_cc(config_file, '\n', ',');
	config_file = clean_text(config_file);
	string[string] c_config;
	
	c_config.parse_options(config_file);
	
	
	/*
	val = "edb.host" in c_config;
	assert(val, "You need to add the parameter 'edb.host' to your config");
	if(val) {
		settings.edb_host = *val;
	}
	
	val = "edb.port" in c_config;
	if(val) {
		settings.edb_port = toUint(*val);
	}
	
	val = "edb.namespace" in c_config;
	if(val) {
		settings.edb_ns = *val;
	}
	*/
	
	val = "root_dir" in c_config;
	if(val) {
		debug {
			if(!Path.exists(*val)) {
				throw new Exception("root directory (" ~ *val ~ ") does not exist");
			}
		}
		
		settings.root_dir = *val;
	}
	
	val = "lang_dir" in c_config;
	assert(val, "You need to add the parameter 'lang_dir' to your config");
	if(val) {
		settings.lang_dir = *val;
	}
	
	val = "panels_dir" in c_config;
	assert(val, "You need to add the parameter 'panels_dir' to your config");
	if(val) {
		settings.panels_dir = *val;
	}
	
	val = "resources" in c_config;
	assert(val, "You need to add the parameter 'resources' to your config");
	if(val) {
		settings.resources_dir = *val;
	}
	
	val = "files" in c_config;
	assert(val, "You need to add the parameter files in your config");
	if(val) {
		settings.static_files = *val;
	}
	
	val = "ouput_buffer_size" in c_config;
	if(val) {
		settings.output_buffer_size = toUint(*val);
	} else {
		settings.output_buffer_size = (1024*512)-1;
	}
	
	val = "site_url" in c_config;
	assert(val, "You need to add the parameter 'site_url' to your config");
	if(val) {
		settings.site_url = *val;
	}
	
	val = "bind_port" in c_config;
	assert(val, "You need to add the parameter 'bind_port' to your config");
	if(val) {
		settings.site_port = *val;
		settings.bind_port = toUint(*val);
	}
	
	val = "bind_ip" in c_config;
	assert(val, "You need to add the parameter 'bind_ip' to your config");
	if(val) {
		string site_ip = *val;
		assert(site_ip.length >= 7 && site_ip.length <= 16, "you have an incorrectly formed 'bind_ip' in your config");
		//4.2.2.1
		int i;
		int last = 0;
		int offset = 0;
		do {
			if(site_ip[i] == '.') {
				settings.bind_ip[offset++] = cast(ubyte)toUint(site_ip[last .. i]);
				last = i+1;
			}
		} while(++i < site_ip.length);
		
		assert(offset == 3);
		settings.bind_ip[3] = cast(ubyte)toUint(site_ip[last .. $]);
	}
	
	val = "optimize_resources" in c_config;
	if(val) {
		settings.optimize_resources = cast(bool)toUint(*val);
	}
	
	val = "reload_panels" in c_config;
	if(val) {
		settings.reload_panels = cast(bool)toUint(*val);
	}
	
	val = "reload_resources" in c_config;
	if(val) {
		settings.reload_resources = cast(bool)toUint(*val);
	}
	
	val = "preserve_newlines" in c_config;
	if(val) {
		settings.preserve_newlines = cast(bool)toUint(*val);
	}
	
	debug {
		noticeln("optimize_resources: ", settings.optimize_resources);
		noticeln("reload_resources: ", settings.reload_resources);
		noticeln("reload_panels: ", settings.reload_panels);
		noticeln("preserve_newlines: ", settings.preserve_newlines);
	}
}

int main(string[] args) {
	signal(SIGABRT, &term_handler);
	signal(SIGTERM, &term_handler);
	signal(SIGQUIT, &term_handler);
	signal(SIGINT, &term_handler);
	signal(SIGVTALRM, &sig_handler);
	signal(SIGALRM, &sig_handler);
	signal(SIGPIPE, &sig_handler);
	
	string config_file = "config";
	for(size_t i; i < args.length; i++) {
		string s = args[i];
		if(s == "-config" && i+1 < args.length) {
			config_file = args[++i];
			debug noticeln("using the config file ", config_file);
		}
	}
	
	assert(config_file != "config", "right now, I do not yet have the ability to make virtual hosts, and I do not yet have the control panel built, so specify the config file on the command like like this -config config.hellacoders");
	parse_config(config_file);
	
	if(settings.root_dir.length) {
		Environment.cwd(settings.root_dir);
	}
	
	/*
	if("log" in c_config) {
		log_file = c_config["log"];
	} else {
		log_file = "furry.log";
	}*/
	
	//TODO!!! - parse the host / port from the config
	edb_init();
	
	debug {
		PNL.reload_resources = true;
	}
	
	Core.init();
	
	debug {
		if(!Path.exists(settings.panels_dir)) {
			mkdir(settings.panels_dir);
		}
		
		if(!Path.exists(settings.resources_dir)) {
			mkdir(settings.resources_dir);
		}
	}
	
	version(unittests) {
		//GC.minimize();
		//GC.reserve(1024 * 1024 * 100);
		RUN_UNITTESTS();
		return 0;
	}
	
	
	
	dyn_connection.init();
	
	
	PNL.reload_panels(settings.panels_dir, settings.lang_dir);
	
	version(upstairs) {
		PNL.func_args = null;
		foreach(pnl; PNL.pnl) {
			/*foreach(k, v; pnl.var_type) {
				pnl.var_type.remove(k);
			}
			
			foreach(k, v; pnl.var_ptr) {
				pnl.var_ptr.remove(k);
			}
			
			foreach(k, v; pnl.obj_funcs) {
				pnl.obj_funcs.remove(k);
			}
			
			foreach(k, v; pnl.obj_loops) {
				pnl.obj_loops.remove(k);
			}*/
			
			pnl.var_type = null;
			pnl.var_ptr = null;
			pnl.obj_funcs = null;
			pnl.obj_loops = null;
			GC.collect();
		}
	}
	
	debug {
		request_time = cast(int)time(null);
		create_default_objects();
	}
	
	// LATER, make this dynamically generated by a template
	load_files();
	
	
	// listen and serve files
	//GC.collect();
	//GC.minimize();
	
	int ret = main_loop();
	
	return ret;
}

void load_files() {
	if(settings.static_files.length) {
		
		string[string] files;
		files.parse_options(settings.static_files);
		foreach(real_name, file_loc; files) {
			FilePath fp = new FilePath(file_loc);
			if(fp.isFolder()) {
				serve_dir(file_loc, real_name);
			} else {
				string data = cast(string)File.get(file_loc);
				serve_file(file_loc, "", data, null);
			}
		}
	}
}

// I am quickly growing tired of this bus driver. She insists on calling out EVERY street we pass in an "outdoor" voice
// It's not that she isn't a good person, but I don't care to hear every street we pass, or even every stop...
// consequently, almost every street along huntington/foothill/route 66 is a bus stop :(
// A perfect example of this is: "SANTA ANITA RACETRACK! -- MOTEL 6!! -- OAKHURST!!"
// Of those, only one is a bus stop, and there was a bus stop inbetween motel 6 and oakhurst that she forgot to call.
// I also noticed she's been calling things twice now too... "rosemead boulevard!... colorado and rosemead!" or 
// "citrus college!.. citrus and APU!... citrus avenue!"

uint in_array(string val, string[] arr) {
	uint i = 0;
	foreach(string v; arr) {
		i++;
		if(val == v) {
			return i;
		}
	}
	
	return 0;
}

//------------------------------------------------
// So, I walked into starbucks tonight after playing WoW for a week straight and then looked at my code and realized that I had no idea what's going on. I completely forgot how to program. I speculate that WoW uses a
// different portion of the brain and I actually excersized that part so much I feel as if I'm in a black cloud when it comes to logic.


//TODO for template system: (14 items)
//-------------------------
//TODO!!! - tests for <%link when not in ajax_mode
//TODO!!  - parse not inside of quotes
//TODO!!  - <%version [version name] [number] %> / <%endversion%>
//TODO!!  - <%versionlist%>
//TODO!!  - variables in <%link
//TODO!!  - multipart/mime form encoding
//TODO!!  - <%interface which defines how a panel can be called -- <%call "function/image.pnl" `var1` "string" `var2` %> -- which calls the panel, and inline replaces the features in.	  
//TODO!	  - jcc (strings and review that action is ored with the var type)
//TODO!	  - add [access_group] to <%version
//TODO!	  - in parse, change endlink and endform to </a> and </form>
//TODO!	  - <%`variable`%>
//TODO!	  - for <%panel with only one panel, make it static and inline the panel


//tashina
//amanda (cute little girl, brown hair)
//elizabeth (kinda shy..., brown hair)
//cassie
//steban (beyond chipper, yet so extremely cool)
// ryan swan (swanie)
//brian (left-handed, bald)
//rudi
//shannon (managerley hair)
//janet (right-handed, hot)
//sally
//ron
//mike
//KC (brown hair)
//paul (guy that never sleeps)
//chuck (the other guy with epilepsy
//priscilla
//tea
//jean

//chad,evan,jamie,rebecca
//Kyle (the guy that moved to Oregon)

//TODO! - this is probably incorrect and also really slow too
string uri_encode(string str) {
	str = replace_cs(str, '%', "%25");
	str = replace_cs(str, '&', "%26");
	str = replace_cs(str, '#', "%23");
	str = replace_cs(str, '+', "%2B");
	str = replace_cs(str, '\r', "%0D");
	str = replace_cs(str, '\n', "%0A");
	str = replace_cs(str, '\'', "%27");
	str = replace_cs(str, '"', "%22");
	//str = replace_cc(str, " ", "+");
	str = replace_cs(str, ' ', "%20");
	
	return str;
}


/*
it's such a trailer trash scenario here... it's really bad
it looks sooo weird! the stew -- smells ok though... surely, I will contract mad cow from this ... "stew"
*/

// THESE CANNOT CHANGE ONCE THE SITE IS IN PRODUCTION
enum {
	ORIENT_0 = 0,
	ORIENT_90 = 1,
	ORIENT_180 = 2,
	ORIENT_270 = 3,
	ORIENT_MASK = 0b110000,
	ORIENT_OFFSET = 4,
}

// THESE CANNOT CHANGE ONCE THE SITE IS IN PRODUCTION (only adding new values)
enum PHOTO_INFO {
	JPG = 0,
	GIF = 1,
	PNG = 2,
	MASK = 0b001111,
	// sound?
	// movies?
}

// THESE CANNOT CHANGE ONCE THE SITE IS IN PRODUCTION
enum PHOTO_OFFSET {
	VOL = 0,
	HASH = 1,
	SIZE = 6,
	INFO = 7,
	UID = 8,
}

// THESE CANNOT CHANGE ONCE THE SITE IS IN PRODUCTION (only adding new values)
enum SIZE {
	SIZE_ORIG = 0,
	SIZE_35 = 1,
	SIZE_55 = 3,
	SIZE_90 = 5,
	SIZE_100 = 9,
	SIZE_290 = 13,
	SIZE_500 = 17,
	SIZE_830 = 21,
	SIZE_1100 = 25,
}

string size_order = ctfe_enc_int(SIZE.SIZE_35) ~
					ctfe_enc_int(SIZE.SIZE_55) ~
					ctfe_enc_int(SIZE.SIZE_90) ~
					ctfe_enc_int(SIZE.SIZE_100) ~
					ctfe_enc_int(SIZE.SIZE_290) ~
					ctfe_enc_int(SIZE.SIZE_500) ~
					ctfe_enc_int(SIZE.SIZE_830) ~
					ctfe_enc_int(SIZE.SIZE_1100) ~
					ctfe_enc_int(SIZE.SIZE_ORIG);


//string dir_template = "/j/%/~/~/~~-----#######";
//--  /j/[vol]/[hash{0}]/[hash{1}]/[hash{2 .. 5}][size][type + orientation][uid]
string get_real_filename(string filename) {
	//assert(filename.length > 14);
	char[9] output = "/j/%/-/-/";
	
	output[3] = filename[0];
	output[5] = filename[1];
	output[7] = filename[2];
	filename = output ~ filename[3 .. $];
	return filename;
}

int get_photo_type(string filename) {
	return dec_int(filename[PHOTO_OFFSET.INFO]) & PHOTO_INFO.MASK;
}

char translate_photo_size(int size) {
	switch(size) {
	case 35: size = SIZE.SIZE_35; break;
	case 55: size = SIZE.SIZE_35; break;
	case 90: size = SIZE.SIZE_90; break;
	case 100: size = SIZE.SIZE_100; break;
	case 290: size = SIZE.SIZE_290; break;
	case 500: size = SIZE.SIZE_500; break;
	case 830: size = SIZE.SIZE_830; break;
	case 1100: size = SIZE.SIZE_1100; break;
	default: return 0;
	}
	
	return enc_char(size);
}

int process_nf(string filename) {
	string resize;
	int size = dec_int(filename[2]);
	switch(size) {
	case SIZE.SIZE_35:
		resize = "35x ";
		break;
	case SIZE.SIZE_55:
		resize = "55x ";
		break;
	case SIZE.SIZE_90:
		resize = "90x ";
		break;
	case SIZE.SIZE_100:
		resize = "100x ";
		break;
	case SIZE.SIZE_290:
		resize = "290x ";
		break;
	case SIZE.SIZE_500:
		resize = "500x ";
		break;
	case SIZE.SIZE_830:
		resize = "830x ";
		break;
	case SIZE.SIZE_1100:
		resize = "1100x ";
		break;
	default:
		return 0;
	}
	
	try {
		auto p = new Process("nice -n 19 convert nf.png -quality 75 -resize " ~ resize ~ " jpg:/j/" ~ filename, null);
		p.execute();
		auto ret = p.wait;
		//ret != ret.Exit;
	} catch(ProcessCreateException e) {
		// there was an exception...
	}
	
	return 1;
}

// [hash][size][foto_info][uid]
int process_photo(string filename) {
	int size = dec_int(filename[PHOTO_OFFSET.SIZE]);
	int orig_size;
	string resize;
	switch(size) {
	case SIZE.SIZE_35:
		resize = "35x ";
		break;
	case SIZE.SIZE_90:
		resize = "90x ";
		break;
	case SIZE.SIZE_100:
		resize = "100x ";
		break;
	case SIZE.SIZE_290:
		resize = "290x ";
		break;
	case SIZE.SIZE_500:
		resize = "500x ";
		break;
	case SIZE.SIZE_830:
		resize = "830x ";
		break;
	case SIZE.SIZE_1100:
		resize = "1100x ";
		break;
	default:
		return 0;
	}
	
	int info = dec_int(filename[PHOTO_OFFSET.INFO]);
	string type;
	
	switch(info & PHOTO_INFO.MASK) {
	default:
	case PHOTO_INFO.JPG:
		type = "jpg:";
		break;
	case PHOTO_INFO.GIF:
		type = "gif:";
		break;
	case PHOTO_INFO.PNG:
		type = "png:";
		break;
	}
	
	int orientation = (info & ORIENT_MASK) >> ORIENT_OFFSET;
	int disk = cast(int)find_c(tostring, filename[PHOTO_OFFSET.VOL]);
	
	if(orientation == ORIENT_90) {
		resize ~= "-rotate 90 ";
	} else if(orientation == ORIENT_180) {
		resize ~= "-rotate 180 ";
	} else if(orientation == ORIENT_270) {
		resize ~= "-rotate 270 ";
	}
	
	int exists;
	string orig_file = filename.dup;
	// the reason why this is a while() is because I want to start at the next sizes up, and I don't want a buffer overrun 
	orig_size = find_c(size_order, enc_char(size))+1;
	while(orig_size > 0) {
		orig_file[PHOTO_OFFSET.SIZE] = size_order[orig_size];
		exists = Path.exists(get_real_filename(orig_file));
		if(exists) {
			orientation = 0;
			break;
		}
		
		orig_size++;
	}
	
	if(orientation != 0) {
		int new_info = info & !ORIENT_MASK; // set it to 0 (orig orientation) by clearing the second two bits
		orig_file[PHOTO_OFFSET.INFO] = enc_char(new_info);
		for(orig_size = find_c(size_order, enc_char(size)); orig_size > 0; orig_size++) {
			orig_file[PHOTO_OFFSET.SIZE] = size_order[orig_size];
			exists = Path.exists(get_real_filename(orig_file));
			if(exists) {
				break;
			}
		}
	}
	
	if(!exists) {
		return 0;
	}
	
	//exec("nice -n 19 convert " ~ get_real_filename(orig_file) ~ " -quality 75 -resize " ~ resize ~ type ~ get_real_filename(filename));
	try {
		auto p = new Process("nice -n 19 convert " ~ get_real_filename(orig_file) ~ " -quality 75 -resize " ~ resize ~ type ~ get_real_filename(filename), null);
		p.execute();
		auto ret = p.wait;
		//ret != ret.Exit;
	} catch(ProcessCreateException e) {
		// there was an exception...
	}
	
	//TODO!! get filesize and try and compress it
	//TODO!! - add a locking mechanism, so two processes are not converting the same file
	// (checks file is not found in an array of current processing images, and if true, place connection in same state as the other connection)
	//TODO!!! - do this in a thread instead, so I don't pause the parent process, and at the end, unlock the connections
	// (I can define x number of conversion threads max)
	return 1;
}

