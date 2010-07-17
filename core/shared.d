module shared;
//import session : Session, UserSession;
import panel;
import lib;
import core;
import session;

version(unittests) public import unittests;
public import externs;
public import tango.core.Memory : GC;
public import tango.util.compress.c.zlib;
public import tango.stdc.time;

version = printtest;

// Object list:
TemplateObject function(inout PNL pnl, string cmd, inout string[string] params)[string] available_objects;
void function(string input)[string] text_transforms;

// [panel name] [object name] [scope] [instance #]
TemplateObject[int][string][string] normal_objects;
int[string][string] instance_count;

// periodic update functions
void function()[] periodic_updates;

string[string] POST;
string[string] FUNC;
string[string] COOKIE;

Session cur_session;
UserSession user_session;
STATS stats;

//TODO!!!! - put these in global struct:
extern(C) {
	string sid;
	string query_string;
	string title;
	int uid;
	uint wid;
	
	int zid;
	uint zid_set;
	int xid;
	uint xid_set;
	
	int browser_type;
	int browser_version;

	uint is_me;
	int request_time;
	
	uint ip4;
}

// global configuration vars
//string site_url;
//string site_port;
//ubyte[4] ip_listen = [127,0,0,1];
//ushort port_listen = 1234;
int last_request_time;

// globals
string key_session;

string[string] PANELS;
void*[string] FILES;
void*[string] FILES_GZIP;

bool in_func;
int in_js;

int func_ret;
string func_name;
string div;
char* out_tmp;
size_t out_ptr = 0;

uint cur_sock;

struct Settings {
	string root_dir;
	string lang_dir;
	string panels_dir;
	string resources_dir;
	string static_files;
	
	int output_buffer_size;
	string site_url;
	string site_port;
	ushort bind_port;
	ubyte[4] bind_ip;
	
	string edb_host;
	string edb_namespace;
	int edb_port;
	
	bool optimize_resources;
	bool reload_panels;
	bool reload_resources;
	bool preserve_newlines;
}

Settings settings;
uint[string] pnl_global_var_type;
char*[string] pnl_global_var_ptr;

size_t buffer_size = (1024 * 1024);
dyn_connection* cur_conn;

struct STATS {
	int hits;
	int pnl_hits;
	int page_hits;
	
	int since_gc;
}



version(unittests) {
	extern(C) void reset_state() {
		out_ptr = 0;
		Core.js_out.length = 0;
		
		PNL.reset_state();
		
		POST = null;
		FUNC = null;
		PANELS = null;
		//TODO!!! - figure out why this crashes the garbage collector. I think it's a GC bug
	}
	
	extern(C) void RUN_UNITTESTS() {
		int total = cast(int) test_suites.length;
		noticeln("-- running ", total, " unittests --");
		
		auto yeah = new char[200000];
		out_tmp = yeah.ptr;
		reset_state();
		
		int current = 1;
		int passed = 0;
		int failed = 0;
		
		//GC.disable();
		//assert(test_suites.length == test_suite_names.length);
		
		foreach(name, u; test_suites) {
			version(printtest) stdoutln("(", current, "/", total, ") ", name ~ "...");
			//Unittest u = test_suites[i];
			
			GC.disable();
			
			try {
				u.prepare();
				u.test();
				
				/*
				for(size_t j = 0; j < u.tests.length; j++) {
					try {
						u.tests[j]();
					} catch(Exception e) {
						noticeln("** failed unittest[", j, "] ", test_suite_names[i], ": ", e.file,"(", e.line, ") ", e.msg);
					} finally {
						u.clean();
					}
					
					test = null;
				}
				*/
				passed++;
			} catch(Exception e) {
				noticeln("** failed unittest ", name, ": ", e.file,"(", e.line, ") ", e.msg);
				failed++;
			} finally {
				u.clean();
				current++;
			}
			
			if(failed) {
				break;
			}
			
			GC.enable();
			//if(current % 16) {
				GC.collect();
			//}
			
			noticeln("complete");
		}
		
		//GC.collect();
		noticeln("-- unittests complete (", passed, "/", current-1, " passed) --");
	}
}


