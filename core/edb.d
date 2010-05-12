module edb;

import tango.stdc.string;
import tango.io.device.File;
import tango.io.FilePath;
import Path = tango.io.Path;
import Integer = tango.text.convert.Integer;
import tango.stdc.time : time;
import tango.core.Memory : GC;

import mongodb;
import lib;
version(unittests) import unittests;

const string model_dir = "models/";

static mongo_connection* conn;
static mongo_connection_options* conn_opts;

struct EDB {
	string host;
	int port;
	string db = "test";
	
	size_t objects_loaded_disk;
	size_t objects_loaded_cache;
	size_t objects_synced;
	size_t objects_created;
	size_t objects_destroyed;
	
	size_t index_loaded_disk;
	size_t index_loaded_cache;
	size_t index_synced;
	size_t index_created;
	size_t index_destroyed;
}

static EDB Edb;

void function()[string] edb_inits;
extern(C) void edb_init(string host = "127.0.0.1", int port = 27017, string db = "test") {
	debug noticeln("-- Initializing edb --");
	FilePath fp_model_dir = new FilePath(model_dir);
	if(!fp_model_dir.exists) {
		fp_model_dir.createFolder();
	}
	
	version(unittests) {
		if(conn) {
			mongo_disconnect(conn);
			mongo_destroy(conn);
		}
	}
	
	conn = cast(mongo_connection*)new byte[mongo_connection.sizeof];
	conn_opts = cast(mongo_connection_options*)new byte[mongo_connection_options.sizeof];
	Edb.host = host.dup;
	Edb.port = port;
	Edb.db = db;
	
	memcpy(conn_opts.host.ptr, Edb.host.ptr, Edb.host.length);
	conn_opts.host[Edb.host.length] = 0;
	conn_opts.port = Edb.port;
	stdoutln(" * connecting to ", cast(char[])conn_opts.host[0 .. Edb.host.length]);
	if(mongo_connect(conn, conn_opts)) {
		//errorln("could not connect to mongo ", cast(char[])conn_opts.host[0 .. Edb.host.length-1], ":", conn_opts.port);
		throw new Exception("could not connect to mongodb on " ~ cast(char[])conn_opts.host[0 .. Edb.host.length-1] ~ ":" ~ Integer.toString(conn_opts.port));
	} else {
		stdoutln(" [DONE]");
	}
	
	debug noticeln("-- Finished Initializing edb --");
	debug noticeln("-- Initializing edb objects --");
	foreach(r; edb_inits) {
		r();
	}
	
	debug noticeln("-- Finished Initializing edb objects --");
}

template FieldFromFUNC(F, T) {
	void FieldFromFUNC(F field, T txt_field) {
		string* ptr_field = txt_field in FUNC;
		if(ptr_field) {
			//field = *ptr_field;
		}
	}
}

template GenDataModel(string name, string data_layout, bool export_template = false, bool load = true) {
	const string GenDataModel = `
	
	import lib;
	import panel;
	import mongodb;
	import tango.stdc.stdlib : rand;
	import tango.stdc.string : memcpy;
	import tango.io.device.File;
	import tango.io.FilePath;
	import Path = tango.io.Path;
	import Integer = tango.text.convert.Integer;
	import tango.core.Memory : GC;
	
	// static shit
	private static Data[long] cache;
	private static string obj_name = "` ~ name ~ `";
	private static string ns;
	static this() {
		edb_inits["`~name~`"] = &edb_init;
		` ~ (export_template ? `
			PNL.registerObj(obj_name, &typeof(this).factory);
		` : ``) ~ `
	}
	
	` ~ (export_template ? `
		private const string NAME = "` ~ name ~ `";
		private long* ptr_id;
		private char*[] dyn_vars;
		
		private static TemplateObject factory(PNL* pnl, inout string[string] params) {
			// factory method to produce these objects :)
			typeof(this) obj = new typeof(this)(pnl, params);
			//static assert(obj.register, "you must add the method to class `~ name ~ ` :: void register(PNL* pnl, string[string] params)");
			obj.register(pnl, params);
			
			foreach(j, b; obj.data.tupleof) {
				string field_name = obj.data.tupleof[j].stringof["obj.data.".length .. $];
				
				static if(is(typeof(obj.data.tupleof[j]) == int)) {
					pnl.registerInt("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == uint)) {
					pnl.registerUint("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == byte)) {
					noticeln("BYTE type not yet supported!");
					//pnl.registerInt("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == ubyte)) {
					noticeln("BYTE type not yet supported!");
					//pnl.registerInt("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == short)) {
					noticeln("SHORT type not yet supported!");
					//pnl.registerInt("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == ushort)) {
					noticeln("SHORT type not yet supported!");
					//pnl.registerInt("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == long)) {
					pnl.registerLong("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == ulong)) {
					pnl.registerUlong("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == float)) {
					pnl.registerFloat("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == double)) {
					noticeln("DOUBLE type not yet supported!");
					//pnl.registerFloat("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				} else static if(is(typeof(obj.data.tupleof[j]) == string)) {
					pnl.registerString("` ~ name ~ `." ~ field_name, &obj.data.tupleof[j]);
				}
			}
			
			pnl.registerLong("` ~ name ~ `._id", &obj._id);
			pnl.registerUint("` ~ name ~ `.current", &obj.current);
			pnl.registerUint("` ~ name ~ `.column", &obj.column);
			//pnl.registerUint("` ~ name ~ `.count", &count);
			pnl.registerFunction("` ~ name ~ `.total", &obj.total);
			pnl.registerLoop("` ~ name ~ `", &obj.loop);
			
			return cast(TemplateObject)obj;
		}
		
		this(PNL* pnl, inout string[string] params) {
			string[string] parsed_params;
			string* ptr_value;
			string value;
			
			ptr_value = "_id" in params;
			if(ptr_value && params.length == 1) {
				// direct id load
				value = *ptr_value;
				if(value[0] == '$') {
					value = value[1 .. $];
					int v_scope = pnl.find_var(value);
					if(v_scope >= 0) {
						auto type = pnl.var_type[v_scope][value];
						//if(type == pnl_action_var_int || type == pnl_action_var_uint) {
						if(type == pnl_action_var_ulong || type == pnl_action_var_long) {
							ptr_id = cast(long*)pnl.var_ptr[v_scope][value];
						}
					}
				} else if(value[0] >= '0' && value[0] <= '9') {
					_id = toUlong(value);
				}
			} else {
				parse_query(pnl, params);
				saved_query = params;
			}
		}
		
		void parse_query(PNL* pnl, inout string[string] params) {
			foreach(field, inout v; params) {
				if(v[0] == '$') {
					string var = v[1 .. $];
					int v_scope = pnl.find_var(var);
					if(v_scope >= 0) {
						auto type = pnl.var_type[v_scope][var];
						v = '$'  ~ Integer.toString(type) ~ ':' ~ Integer.toString(dyn_vars.length) ~ '$';
						if(type == pnl_action_var_str) {
							dyn_vars ~= cast(char*) pnl.var_str[v_scope][var];
						//TODO!!! - add functions - registerFunction()
						} else {
							dyn_vars ~= pnl.var_ptr[v_scope][var];
						}
						
						//if(type == pnl_action_var_ulong || type == pnl_action_var_long) {
						//	ptr_id = cast(long*)pnl.var_ptr[v_scope][value];
						//}
					}
				} else if(v[0] == '{') {
					// TODO nested variables... for now, 1 level...
					string[string] nested;
					parse_options(v, nested);
					parse_query(pnl, nested);
					v = make_json(nested);
				}
			}
		}
		
		` ~ (load ? `
			protected void load() {
				long id = _id;
				if(ptr_id) {
					id = *ptr_id;
				}
				
				
				if(id) {
					load(id);
				} else {
					load(saved_query, page_offset, page_size);
				}
			}
		` : ``) ~ `
	` : ``) ~ `
	
	private static void edb_init() {
		// remember the namespace
		noticeln("intializing edb::", Edb.db, ".` ~ name ~ `");
		typeof(this).ns = Edb.db ~ ".` ~ name ~ `\0";
		typeof(this).ns.length = typeof(this).ns.length - 1;
		
		// init the object
		Data d;
		string obj_structure;
		int obj_version = 0;
		string new_structure_string;
		
		foreach(j, b; d.tupleof) {
			char field_type = 0;
			string field_name = d.tupleof[j].stringof[2 .. $];
			
			static if(is(typeof(d.tupleof[j]) == int) || is(typeof(d.tupleof[j]) == uint)) {
				field_type = 'i';
			} else static if(is(typeof(d.tupleof[j]) == string)) {
				field_type = 's';
			} else static if(is(typeof(d.tupleof[j]) == long) || is(typeof(d.tupleof[j]) == ulong)) {
				field_type = 'I';
			} else static if(is(typeof(d.tupleof[j]) == float)) {
				field_type = 'f';
			} else static if(is(typeof(d.tupleof[j]) == byte) || is(typeof(d.tupleof[j]) == ubyte)) {
				field_type = 'b';
			} else static if(is(typeof(d.tupleof[j]) == short) || is(typeof(d.tupleof[j]) == ushort)) {
				field_type = 'w';
			}
			
			if(field_type) {
				new_structure_string ~= field_name ~ ":'*',\n";
				new_structure_string[$-4] = field_type;
			} else {
				errorln("unknown type for ", obj_name, ".", field_name);
			}
		}
		
		obj_structure = new_structure_string[0 .. $-2];
		
		string find_obj_structure = obj_structure;
		bool find_obj_version(FilePath fp) {
			string filename = fp.toString();
			size_t offset = find_c(filename, '@');
			if(offset != -1) {
				string structure_string = cast(string)File.get(filename);
				if(structure_string == obj_structure) {
					if(obj_version) {
						Path.remove(filename);
					} else {
						obj_version = toUint(filename[++offset .. $]);
					}
					
					//return false;
				}
			}
			
			return true;
		}
		
		scan_dir(FilePath(model_dir), &find_obj_version);
		
		if(obj_version == 0) {
			obj_version = cast(int)time(null) - 1;
			string structure_file;
			string structure_file_path;
			do {
				structure_file = obj_name ~ '@' ~ Integer.toString(++obj_version);
				structure_file_path = model_dir ~ structure_file;
			}while(Path.exists(structure_file_path));
			
			File.set(structure_file_path, obj_structure);
		}
	}
	
	static mongo_cursor* query(bson* bson_query, int page_offset, int page_size) {
		mongo_cursor* c;
		
		//noticeln("finding... LIMIT ", page_offset * page_size, ", ", page_size, " ...");
		//bson_print(bson_query);
		
		c = mongo_find(conn, ns.ptr, bson_query, null, page_size, page_offset * page_size, 0);
		
		version(extra_checks) {
			bson err;
			if(mongo_cmd_get_last_error(conn, Edb.db.ptr, &err)) {
				bson_print(&err);
			}
			
			bson_destroy(&err);
		}
		
		return c;
	}
	
	static long total(bson* query) {
		//noticeln("total...");
		//bson_print(query);
		
		return mongo_count(conn, Edb.db.ptr, obj_name.ptr, query);
	}
	
	long total(string query) {
		bson b;
		make_query(query, &b);
		long r = total(&b);
		bson_destroy(&b);
		return r;
	}
	
	
	
	bson make_bson_struct() {
		bson b;
		bson_buffer bb;
		bson_buffer_init(&bb);
		
		foreach(j, caca; data.tupleof) {
			string field = this.data.tupleof[j].stringof["this.data.".length .. $];
			
			static if(is(typeof(data.tupleof[j]) == ubyte) || is(typeof(data.tupleof[j]) == byte)) {
				// int1
				bson_append_int(&bb, field.ptr, data.tupleof[j]);
			} else static if(is(typeof(data.tupleof[j]) == ushort) || is(typeof(data.tupleof[j]) == short)) {
				// int2
				bson_append_int(&bb, field.ptr, data.tupleof[j]);
			} else static if(is(typeof(data.tupleof[j]) == uint) || is(typeof(data.tupleof[j]) == int)) {
				// int4
				bson_append_int(&bb, field.ptr, data.tupleof[j]);
			} else static if(is(typeof(data.tupleof[j]) == float)) {
				// float4
				bson_append_double(&bb, field.ptr, cast(double)data.tupleof[j]);
			} else static if(is(typeof(data.tupleof[j]) == double)) {
				// float8
				bson_append_double(&bb, field.ptr, cast(double)data.tupleof[j]);
			} else static if(is(typeof(data.tupleof[j]) == ulong) || is(typeof(data.tupleof[j]) == long)) {
				// int8
				bson_append_long(&bb, field.ptr, data.tupleof[j]);
			} else static if(is(typeof(data.tupleof[j]) == string)) {
				// string(word)
				bson_append_substr(&bb, field.ptr, data.tupleof[j].ptr, data.tupleof[j].length);
			} else {
				static assert(false, "no bson conversion for " ~ data.tupleof[j].stringof);
			}
		}
		
		bson_from_buffer(&b, &bb);
		return b;
	}

	
	// this is going to be very hard to implement on mongodb.. what I could do though, is implement
	// a module in mongodb which allows servers to register hooks based on queries, and if it's true, send a notification
	// there's also a way of opening cursors in the database and querying on a regular basis
	//static void function(int id, Data* data)[] create_hooks;
	//static void function(int id, Data* data)[] destroy_hooks;
	//static void function(int id, Data* data_old, Data* data_new)[] sync_hooks;
	
	
	// NON static stuff
	//=============
	
	//OPTIMIZE!!!! - remove the align, since we use tupleof[] now
	struct Data {
		align(1):
		long _id;
		` ~ data_layout ~ `
	}
	
	union {
		private Data data;
		struct {
			align(1):
			long _id;
			` ~ data_layout ~ `
		}
	}
	
	
	// looping stuff
	private bool skip_loop;
	private uint current = -1;
	private uint column = -1;
	//uint total;
	//uint count;
	
	private uint* ptr_page_offset;
	private uint* ptr_page_size;
	private uint* ptr_width;
	private uint width = 4;
	private uint page_offset = 0;
	private uint page_size = 1;
	private string[string] saved_query;
	private mongo_cursor* cursor;
	
	this() {
		//std.gc.addRange(&data, &data+data.sizeof);
		//GC.addRange(&data, data.sizeof);
		//GC.addRange(&cursor, (mongo_cursor*).sizeof);
	}
	
	this(string str_query, int page_offset = 0, int page_size = 1) {
		this();
		//string[string] query;
		parse_options(str_query, saved_query, true);
		if(load(saved_query, page_offset, page_size)) {
			loop();
		} else {
			
		}
	}
	
	this(bson* bson_query, int page_offset = 0, int page_size = 1) {
		query(bson_query, page_offset, page_size);
		this();
	}
	
	this(long id) {
		this();
		page_size = 1;
		page_offset = 0;
		
		if(id != 0) {
			this._id = id;
			
			if(!load(id)) {
				this._id = -id;
			}
		}
	}
	
	// cleanup?
	~this() {
		mongo_cursor_destroy(cursor);
		cursor = null;
	}
	
	int load(long id) {
		bson b;
		bson_buffer bb;
		bson_buffer_init(&bb);
		bson_append_long(&bb, "_id", id);
		bson_from_buffer(&b, &bb);
		
		cursor = query(&b, 0, 1);
		auto ret = loop();
		mongo_cursor_destroy(cursor);
		bson_destroy(&b);
		return this._id;
	}
	
	int load(inout string[string] parsed_query, int page_offset = 0, int page_size = 1) {
		this.page_size = page_size;
		this.page_offset = page_offset;
		
		bson b;
		make_query(parsed_query, &b);
		query_pnl(&b, this.page_offset, this.page_size);
		bson_destroy(&b);
		
		return cursor != null;
	}
	
	int query_pnl(bson* bson_query, int page_offset, int page_size) {
		this.page_size = page_size;
		this.page_offset = page_offset;
		current = -1;
		column = -1;
		
		mongo_cursor_destroy(cursor);
		cursor = query(bson_query, page_offset, page_size);
		loop();
		if(cursor != null) {
			skip_loop = true;
		}
		
		return cursor != null;
	}
	
	int loop() {
		if(skip_loop == true) {
			skip_loop = false;
			// do nothing!
		} else if(++current != page_size && cursor && mongo_cursor_next(cursor)) {
			// increment the helper variables
			if(++column >= width) {
				column = 0;
			}
			
			Data* ptr_data = &data;
			bson_iterator it;
			
			foreach(j, fn; data.tupleof) {
				string field_name = this.data.tupleof[j].stringof["this.data.".length .. $];
				bson_type type_bson = bson_find(&it, &cursor.current, field_name.ptr);
				switch(type_bson) {
					case bson_type.bson_int:
					case bson_type.bson_long:
					case bson_type.bson_double:
					case bson_type.bson_bool:
					case bson_type.bson_null:
						if(type_bson == bson_type.bson_double) {
							static if(is(typeof(data.tupleof[j]) == float)) {
								data.tupleof[j] = cast(float)bson_iterator_double(&it);
								continue;
							} else static if(is(typeof(data.tupleof[j]) == double)) {
								data.tupleof[j] = cast(double)bson_iterator_double(&it);
								continue;
							}
							
							noticeln("sorry, not yet supported");
						} else {
							long value = 0;
							if(type_bson == bson_type.bson_int) {
								value = bson_iterator_int(&it);
							} else if(type_bson == bson_type.bson_long) {
								value = bson_iterator_long(&it);
							} else if(type_bson == bson_type.bson_bool) {
								value = bson_iterator_bool(&it);
							}
						
							static if(is(typeof(data.tupleof[j]) == ubyte) || is(typeof(data.tupleof[j]) == byte)) {
								data.tupleof[j] = cast(ubyte) value;
							} else static if(is(typeof(data.tupleof[j]) == ushort) || is(typeof(data.tupleof[j]) == short)) {
								data.tupleof[j] = cast(ushort) value;
							} else static if(is(typeof(data.tupleof[j]) == uint) || is(typeof(data.tupleof[j]) == int)) {
								data.tupleof[j] = cast(uint) value;
							} else static if(is(typeof(data.tupleof[j]) == ulong) || is(typeof(data.tupleof[j]) == long)) {
								data.tupleof[j] = cast(ulong) value;
							}
						}
						
						break;
						
					case bson_type.bson_string:
						size_t len = bson_iterator_string_len(&it) - 1;
						char* ptr_str = bson_iterator_string(&it);
						
						static if(is(typeof(data.tupleof[j]) == string)) {
							data.tupleof[j].length = len;
							memcpy(data.tupleof[j].ptr, ptr_str, len);
						} else {
							errorln("not yet supported");
						}
						
						break;
					
					default:
						// this means that the field exists in the object, but not in the bson... so, I should apply the default value!
						//assert(false, "no bson conversion for " ~ data.tupleof[j].stringof ~ " native(" ~ typeof(data.tupleof[j]).stringof ~ ") bson(" ~ Integer.toString(type_bson) ~ ")");
				}
			}
			
			//TODO!!!! - prepare an update query here deleting the extra fields (this will be executed on object save)
			
			/*
			// delete all remaining fields
			bson_iterator_init(&it, o.data);
			while(bson_iterator_next(&it)) {
				
			}
			*/
			
		} else {
			mongo_cursor_destroy(cursor);
			cursor = null;
			_id = 0;
			skip_loop = false;
			return false;
		}
		/*
		// build file string..
		string name = obj_name ~ build_id_str(id);
		
		Data* exists = name in cache;
		if(exists) {
			debug noticeln("loaded from cache... ", name);
			memcpy(&data, exists, Data.sizeof);
			Edb.objects_loaded_cache++;
			return true;
		}
		
		// get file contents
		ubyte[] serialized;
		if(Path.exists(data_dir ~ name)) {
			serialized = cast(ubyte[])File.get(data_dir ~ name);
			Edb.objects_loaded_disk++;
		} else {
			return false;
		}
			
		// get version
		int ver = serialized[$-1];
		// load struct
		if(ver == obj_version) {
			debug noticeln("loaded from disk... ", name);
			load_struct(field_types, serialized.ptr, &data);
		} else if(ver+1 == obj_version) {
			noticeln("upgrading +1 (", ver, "->", obj_version, ") ", name);
			upgrade_1_version(name, serialized, data);
		} else if(ver < obj_version) {
			noticeln("upgrading +", obj_version - ver, " (", ver, "->", obj_version, ") ", name);
			upgrade_many_versions(name, serialized, ver, data);
		}
		
		cache[name] = data;
		*/
		
		return true;
	}
	
	long save() {
		bson err;
		bson b;
		
		bool is_new = true;
		if(_id == 0) {
			_id = find_id();
		} else if(_id < 0) {
			_id = -_id;
		} else {
			is_new = false;
		}
		
		b = make_bson_struct();
		//noticeln("saving... ", _id);
		//bson_print(&b);
		
		if(!is_new) {
			bson cond;
			bson_buffer bb;
			bson_buffer_init(&bb);
			bson_append_long(&bb, "_id", _id);
			bson_from_buffer(&cond, &bb);
			mongo_update(conn, ns.ptr, &cond, &b, /*MONGO_UPDATE_UPSERT*/ 0);
			bson_destroy(&cond);
			version(extra_checks) {
				if(mongo_cmd_get_last_error(conn, Edb.db.ptr, &err)) {
					bson_print(&err);
				}
			}
		}
		
		if(is_new) {
			while(true) {
				
				mongo_insert(conn, ns.ptr, &b);
				if(mongo_cmd_get_last_error(conn, Edb.db.ptr, &err)) {
					bson_print(&err);
					bson_destroy(&err);
					_id = find_id();
					
					bson_destroy(&b);
					b = make_bson_struct();
				} else {
					break;
				}
			}
		}
		
		bson_destroy(&err);
		bson_destroy(&b);
		
		/*
		
		// build file string
		ubyte[] serialized = save_struct(field_types, cast(void*)&data, obj_version);
		// output file
		//string dir = data_dir ~ obj_name;
		string id_str = build_id_str(id);
		string name = obj_name ~ id_str;
		
		if(!is_new) {
			Edb.objects_synced++;
			Data* data_exists = name in cache;
			Data* old_data = data_exists;
			if(!data_exists) {
				Data d;
				//load(id, d);
				old_data = &d;
			}
			
			foreach(s; sync_hooks) {
				s(id, old_data, &data);
			}
			
			if(*old_data == data) {
				debug noticeln("not saving (data is the same) ", name);
				return 0;
			}
			
			if(data_exists) {
				*data_exists = data;
			} else {
				cache[name] = *old_data;
			}
			
		} else {
			Edb.objects_created++;
			GC.addRoot(&data);
			cache[name] = data;
			
			string dir = data_dir ~ obj_name;
			if(id_str.length > 3) {
				debug {
					if(!Path.exists(data_dir ~ obj_name)) {
						mkdir(data_dir ~ obj_name);
					}
				}
				
				if(!Path.exists(dir ~ id_str[0 .. 2])) {
					mkdir(dir ~ id_str[0 .. 2]);
				}
				
				if(id_str.length > 5 && !Path.exists(dir ~ id_str[0 .. 4])) {
					mkdir(dir ~ id_str[0 .. 4]);
				}
			}
			
			foreach(s; create_hooks) {
				s(id, &data);
			}
		}
		
		
		
		string file = data_dir ~ name;
		
		try {
			File.set(file, serialized);
			debug noticeln("saving (", obj_version, ") ", name);
			return 0;
		} catch(Exception e) {
			return FAILURE;
		}
		*/
		return _id;
	}
	
	int destroy() {
		//TODO!!!! - destroy the object
		bson b;
		bson_buffer bb;
		bson_buffer_init(&bb);
		bson_append_long(&bb, "_id", _id);
		bson_from_buffer(&b, &bb);
		mongo_remove(conn, ns.ptr, &b);
		bson_destroy(&b);
		
		
		/*
		if(id > 0) {
			string name = obj_name ~ build_id_str(id);
			string file = data_dir ~ name;
			if(Path.exists(file)) {
				Data* data_exists = name in cache;
				if(data_exists) {
					Edb.objects_loaded_cache++;
					foreach(s; destroy_hooks) {
						s(id, data_exists);
					}
				
					cache.remove(name);
				}
				
				Edb.objects_destroyed++;
				Path.remove(file);
				return 0;
			}
		}
		*/
		
		return FAILURE;
	}
	
	private int find_id() {
		// for now, this is done by random, but later, order this based on the server array
		while(true) {
			int id = rand();
			if(id <= 0) {
				id = -id;
			}
			
			//string name = obj_name ~ build_id_str(id);
			//Data* data_exists = name in cache;
			//if(!data_exists && !Path.exists(name)) {
				return id;
			//}
		}
		
		return 0;
	}
	
	private void make_query(string str_query, bson* b) {
		string[string] query;
		parse_options(str_query, query, false);
		make_query(query, b);
	}
	
	private void make_query(inout string[string] parsed_query, bson* b) {
		bson_buffer bb;
		string orderby;
		string hint;
		
		bson_buffer_init(&bb);
		if(parsed_query != null) {
			// the following foreach has problems with ldc-0.9.2... tired of fixing D's bugs!
			//foreach(label, val; parsed_query) {
			foreach(label; parsed_query.keys) {
				string val = parsed_query[label];
				bool remove = true;
				string label0 = label ~ '\0';
				
				size_t val_length = val.length;
				if(val_length) {
					
					switch(label) {
					case "$page_size":
					case "$limit":
						//TODO(0.2) - make a generic function to get the value based on it being a literal or a variable
						page_size = toUint(val);
						break;
						
					case "$column_width":
						//TODO(0.2) - make a generic function to get the value based on it being a literal or a variable
						width = toUint(val);
						break;
						
					case "$page":
					case "$page_offset":
						//TODO(0.2) - make a generic function to get the value based on it being a literal or a variable
						page_offset = toUint(val);
						break;
						
					case "$orderby":
						orderby = val;
						break;
						
					case "$hint":
						hint = val;
						break;
						
					default:
						remove = false;
						if(val == "null") {
							bson_append_null(&bb, label0.ptr);
						} else if(val == "undefined") {
							bson_append_undefined(&bb, label0.ptr);
						} else if(val.ptr) {
							if(val_length > 1) {
								char v1 = val[0];
								char v2 = val[$-1];
							
								if((v1 == '\"' && v2 == '\"') || (v1 == '\'' && v2 == '\'')) {
									// string
									bson_append_substr(&bb, label0.ptr, &val[1], val_length - 2);
									break;
								} else if(v1 == '{' && v2 == '}') {
									// object
									bson obj_b;
									make_query(val, &obj_b);
									bson_append_bson(&bb, label0.ptr, &obj_b);
									bson_destroy(&obj_b);
									break;
								}
								` ~ (export_template ? `
								else if(v1 == '$' && v2 == '$') {
										// template variable
										auto scope_offset = find_c(val, ':', 2);
										if(scope_offset != -1) {
											int type = toUint(val[1 .. scope_offset]);
											int dyn_var = toUint(val[++scope_offset .. $-1]);
											
											if(dyn_var < dyn_vars.length) {
												auto ptr_var = dyn_vars[dyn_var];
												
												if(type == pnl_action_var_ulong || type == pnl_action_var_long) {
													bson_append_long(&bb, label0.ptr, *cast(long*) ptr_var);
													break;
												} else if(type == pnl_action_var_uint || type == pnl_action_var_int) {
													bson_append_int(&bb, label0.ptr, *cast(int*) ptr_var);
													break;
												} else if(type == pnl_action_var_str) {
													string tmp = *cast(string*) ptr_var;
													//bson_append_long(&bb, label0.ptr, *cast(int*) ptr_var);
													bson_append_substr(&bb, label0.ptr, tmp.ptr, tmp.length);
													break;
												} else {
													debug throw new Exception("unknown variable type");
												}
											} else {
												debug throw new Exception("variable doesn't exist!");
											}
										}
										
										break;
								}
								` : ``) ~ `
								else if(find_c(label, '.') != -1) {
									//TODO(0.2) - toDouble function
									double val_d = toFloat(val);
									bson_append_double(&bb, label0.ptr, val_d);
									break;
								}
							}
							
							long val_l = toLong(val);
							if(val_l < int.max && val_l > int.min) {
								bson_append_int(&bb, label0.ptr, cast(int) val_l);
							} else {
								bson_append_long(&bb, label0.ptr, val_l);
							}
						}
					}
					
					//if(remove) {
					//	parsed_query.remove(label);
					//}
				}
			}
		}
		
		if(orderby != null || hint != null) {
			//bson_buffer_init(&bb);
			bson_buffer bb2;
			
			bson bson_query;
			bson bson_orderby;
			bson bson_hint;
			bson_buffer_init(&bb2);
			
			bson_from_buffer(&bson_query, &bb);
			bson_append_bson(&bb2, "query", &bson_query);
			
			if(orderby != null) {
				make_query(orderby, &bson_orderby);
				bson_append_bson(&bb2, "orderby", &bson_orderby);
			}
			
			if(hint != null) {
				make_query(hint, &bson_hint);
				bson_append_bson(&bb2, "hint", &bson_hint);
			}
			
			bson_from_buffer(b, &bb2);
		} else {
			bson_from_buffer(b, &bb);
		}
	}
	`;
}

/*
string build_id_str(size_t id) {
	string id_str = Integer.toString(id);
	switch(id_str.length) {
	case 1:
		string dir = "/#_".dup;
		dir[2] = id_str[0];
		return dir;
	case 2:
		string dir = "/_/#_".dup;
		dir[1] = id_str[0];
		dir[4] = id_str[1];
		return dir;
	case 3:
		string dir = "/_/_/#_".dup;
		dir[1] = id_str[0];
		dir[3] = id_str[1];
		dir[6] = id_str[2];
		return dir;
	default:
	}
	
	string dir = "/_/_/#".dup;
	dir[1] = id_str[0];
	dir[3] = id_str[1];
	return dir ~ id_str[2 .. $];
}

ubyte[] save_struct(string schema, void* data_ptr, uint obj_ver) {
	ubyte[] data;
	void* ptr = data_ptr;
	void* ptr_save = ptr;
	size_t length = 0;
	foreach(s; schema) {
		switch(s) {
		case 'b': // int1
			length += ubyte.sizeof;
			ptr += ubyte.sizeof;
			break;
		
		case 'w': // int2
			length += ushort.sizeof;
			ptr += ushort.sizeof;
			break;
			
		case 'i': // int4
		case 'f': // float4
			length += uint.sizeof;
			ptr += uint.sizeof;
			break;
			
		case 'I': // int8
			length += ulong.sizeof;
			ptr += ulong.sizeof;
			break;
			
		case 's': // string2
			length += 2;
			string tmp = *cast(string*)ptr;
			
			length += tmp.length;
			ptr += tmp.sizeof;
			break;
			
		case 'S': // string(4)
			length += 4;
			string tmp = *cast(string*)ptr;
			
			length += tmp.length;
			ptr += tmp.sizeof;
			
		default:
			//errorln("ERROR, unknown schema type: ", s);
		}
	}
	
	ptr = ptr_save;
	
	data.length = length + 1;
	void* ptr_out = data.ptr;
	
	
	foreach(s; schema) {
		switch(s) {
		case 'b': // int1
			*cast(ubyte*)ptr_out = *cast(ubyte*)ptr;
			ptr_out += ubyte.sizeof;
			ptr += ubyte.sizeof;
			break;
			
		case 'w': // int2
			*cast(ushort*)ptr_out = *cast(ushort*)ptr;
			ptr_out += ushort.sizeof;
			ptr += ushort.sizeof;
			break;
			
		case 'i': // int4
		case 'f': // float4
			*cast(uint*)ptr_out = *cast(uint*)ptr;
			ptr_out += uint.sizeof;
			ptr += uint.sizeof;
			break;
			
		case 'I': // int8
			*cast(ulong*)ptr_out = *cast(ulong*)ptr;
			ptr_out += ulong.sizeof;
			ptr += ulong.sizeof;
			break;
			
		case 's': // string2
			string tmp = *cast(string*)ptr;
			*cast(ushort*)ptr_out = cast(ushort)tmp.length;
			ptr_out += 2;
			memcpy(ptr_out, tmp.ptr, tmp.length);
			ptr_out += tmp.length;
			ptr += string.sizeof;
			break;
			
		case 'S': // string(4)
			string tmp = *cast(string*)ptr;
			*cast(uint*)ptr_out = cast(uint)tmp.length;
			ptr_out += 4;
			memcpy(ptr_out, tmp.ptr, tmp.length);
			ptr_out += tmp.length;
			ptr += string.sizeof;
			break;
			
		default:
			errorln("ERROR, unknown schema type: ", s);
		}
	}
	
	*cast(ubyte*)ptr_out = cast(ubyte)obj_ver;
	
	return data;
}

void load_struct(string schema, ubyte* data_ptr, void* struct_ptr) {
	ubyte* ptr_data = data_ptr;
	void* ptr_struct = struct_ptr;
	
	for(size_t i = 0; i < schema.length; i++) {
		char s = schema[i];
		switch(s) {
		case 'b': // int1
			*cast(ubyte*)ptr_struct = *cast(ubyte*)ptr_data;
			ptr_struct += ubyte.sizeof;
			ptr_data += ubyte.sizeof;
			break;
			
		case 'w': // int2
			*cast(ushort*)ptr_struct = *cast(ushort*)ptr_data;
			ptr_struct += ushort.sizeof;
			ptr_data += ushort.sizeof;
			break;
			
		case 'i': // int4
		case 'f': // float4
			*cast(uint*)ptr_struct = *cast(uint*)ptr_data;
			ptr_struct += uint.sizeof;
			ptr_data += uint.sizeof;
			break;
			
		case 'I': // int8
			*cast(ulong*)ptr_data = *cast(ulong*)ptr_struct;
			ptr_struct += ulong.sizeof;
			ptr_data += ulong.sizeof;
			break;
			
		case 's': // string2
			*cast(string*)ptr_struct = string.init;
			size_t len = *cast(ushort*)ptr_data;
			(*cast(string*)ptr_struct).length = len;
			ptr_data += 2;
			memcpy((*cast(string*)ptr_struct).ptr, ptr_data, len);
			GC.addRoot((*cast(string*)ptr_struct).ptr); // bad hack
			
			ptr_data += len;
			ptr_struct += string.sizeof;
			break;
			
		case 'S': // string(4)
			*cast(string*)ptr_struct = string.init;
			size_t len = *cast(uint*)ptr_data;
			(*cast(string*)ptr_struct).length = len;
			ptr_data += 4;
			memcpy((*cast(string*)ptr_struct).ptr, ptr_data, len);
			GC.addRoot((*cast(string*)ptr_struct).ptr); // bad hack
			
			
			ptr_data += len;
			ptr_struct += string.sizeof;
			break;
		
		case 'N': // create a new field
			s = schema[++i];
			switch(s) {
			case 'b':
				*cast(ubyte*)ptr_struct = 0;
				ptr_struct += ubyte.sizeof;
				break;
				
			case 'w':
				*cast(ushort*)ptr_struct = 0;
				ptr_struct += ushort.sizeof;
				break;
				
			case 'i':
			case 'f':
				*cast(uint*)ptr_struct = 0;
				ptr_struct += uint.sizeof;
				break;
				
			case 'I':
				*cast(ulong*)ptr_struct = 0;
				ptr_struct += ulong.sizeof;
				break;
				
			case 's':
			case 'S':
				string tmp;
				*cast(string*)ptr_struct = tmp;
				GC.addRoot((*cast(string*)ptr_struct).ptr); // bad hack
				ptr_struct += string.sizeof;
				break;
				
			default:
				errorln("Unknown new field type ", s);
			}
			
			break;
		
		case 'U': // upgrade a field
			s = schema[++i];
			switch(s) {
			case 'I':
				*cast(uint*)ptr_struct = 0;
				ptr_struct += uint.sizeof;
				break;
				
			case 'S':
				string tmp;
				*cast(string*)ptr_struct = tmp;
				GC.addRoot((*cast(string*)ptr_struct).ptr); // bad hack
				ptr_struct += string.sizeof;
				break;
				
			default:
				errorln("You cannot upgrade field type ", s);
			}
			
			break;
			
		case '*': // skip the next field
			s = schema[++i];
			switch(s) {
			case 'b':
				ptr_data += ubyte.sizeof;
				break;
				
			case 'w':
				ptr_data += ushort.sizeof;
				break;
				
			case 'i':
				ptr_data += uint.sizeof;
				break;
				
			case 'I':
				ptr_data += ulong.sizeof;
				break;
				
			case 's':
				ptr_data += *cast(ushort*)ptr_data;
				ptr_data += 2;
				break;
				
			case 'S':
				ptr_data += *cast(uint*)ptr_data;
				ptr_data += 4;
				break;
				
			default:
				errorln("Unknown delete field type ", s);
			}
			
			break;
			
		default:
			errorln("ERROR, unknown schema type: ", s);
		}
		
		version(unittests) {
			if(cast(size_t)ptr_struct % (size_t).sizeof != 0) {
				errorln("DANGER!!!! - data field #", i, " is misaligned! - this will cause random crashes");
			}
		}
	}
}
*/

version(unittests) {
	import panel;
	
	class Test_mongodb : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		
		
		string unit_ns = "test.testing";
		string unit_db = "test";
		string unit_collection = "testing";
		
		void prepare() {
			mongo_cmd_drop_collection(conn, unit_db.ptr, unit_collection.ptr, null);
		}
		
		void clean() {
			mongo_cmd_drop_collection(conn, unit_db.ptr, unit_collection.ptr, null);
		}
		
		void test() {
			bson b;
			bson obj;
			bson err;
			bson_buffer bb;
			mongo_cursor* cursor;
			bson_iterator it;
				
			// insert #1
			bson_buffer_init(&bb);
			bson_append_long(&bb, "id", 1234);
			bson_from_buffer(&b, &bb);
			mongo_insert(conn, unit_ns.ptr, &b);
			bson_destroy(&b);
			version(extra_checks) assert(!mongo_cmd_get_last_error(conn, unit_db.ptr, &err));
			version(extra_checks) bson_destroy(&err);
			
			// insert #2
			bson_buffer_init(&bb);
			bson_append_long(&bb, "id", 1026);
			bson_from_buffer(&b, &bb);
			mongo_insert(conn, unit_ns.ptr, &b);
			bson_destroy(&b);
			version(extra_checks) assert(!mongo_cmd_get_last_error(conn, unit_db.ptr, &err));
			version(extra_checks) bson_destroy(&err);
			
			// find only one
			bson_buffer_init(&bb);
			bson_append_long(&bb, "id", 1234);
			bson_from_buffer(&b, &bb);
			cursor = mongo_find(conn, unit_ns.ptr, &b, null, 10, 0, 0);
			bson_destroy(&b);
			
			int count = 0;
			while(mongo_cursor_next(cursor)) {
				bson_copy(&b, &cursor.current);
				bson_destroy(&b);
				count++;
				
				assert(count != 1 || bson_find(&it, &cursor.current, "id") == bson_type.bson_long);
				assert(count != 1 || bson_iterator_long(&it) == 1234);
			}
			
			mongo_cursor_destroy(cursor);
			assert(count == 1);
			
			// find all
			bson_empty(&b);
			cursor = mongo_find(conn, unit_ns.ptr, &b, null, 10, 0, 0);
			bson_destroy(&b);
			
			count = 0;
			while(mongo_cursor_next(cursor)) {
				bson_copy(&b, &cursor.current);
				bson_destroy(&b);
				count++;
			}
			
			assert(count == 2);
			mongo_cursor_destroy(cursor);
			
			// find none
			bson_buffer_init(&bb);
			bson_append_long(&bb, "id", 1111);
			bson_from_buffer(&b, &bb);
			cursor = mongo_find(conn, unit_ns.ptr, &b, null, 1, 0, 0);
			bson_destroy(&b);
			
			count = 0;
			while(mongo_cursor_next(cursor)) {
				bson_copy(&b, &cursor.current);
				bson_destroy(&b);
				count++;
			}
			
			mongo_cursor_destroy(cursor);
			assert(count == 0);
			
			
		}
	}
	
	
	class UserDataModelVersion1 {
		mixin(GenDataModel!("UnittestUser", `
			int uid;
			string firstname;
			string lastname;
		`));
	}
	
	static assert(UserDataModelVersion1.Data.sizeof == (long.sizeof + int.sizeof + string.sizeof*2));
	
	class UserDataModelVersion2 {
		mixin(GenDataModel!("UnittestUser", `
			int uid;
			string firstname;
			string newfield;
			string lastname;
		`));
	}
	
	static assert(UserDataModelVersion2.Data.sizeof == (long.sizeof + int.sizeof + string.sizeof*3));
	
	class UserDataModelVersion3 {
		mixin(GenDataModel!("UnittestUser", `
			int uid;
			string firstname;
			string lastname;
		`));
	}
	
	static assert(UserDataModelVersion3.Data.sizeof == (long.sizeof + int.sizeof + string.sizeof*2));
	
	class UserDataModelVersion4 {
		mixin(GenDataModel!("UnittestUser", `
			int uid;
			string firstname;
			int d_created;
			string lastname;
		`));
	}
	
	static assert(UserDataModelVersion4.Data.sizeof == (long.sizeof + int.sizeof*2 + string.sizeof*2));
	
	class UserDataModelVersion5 {
		mixin(GenDataModel!("UnittestUser", `
			int uid;
			int d_created;
			string firstname;
			string lastname;
		`));
	}
	
	static assert(UserDataModelVersion5.Data.sizeof == (long.sizeof + int.sizeof*2 + string.sizeof*2));
	
	class UserDataModelVersion6 {
		mixin(GenDataModel!("UnittestUser", `
			int uid;
			int d_created;
			string firstname;
			string middlename;
			string lastname;
		`));
	}
	
	static assert(UserDataModelVersion6.Data.sizeof == (long.sizeof + int.sizeof*2 + string.sizeof*3));
	
	class UserDataModelVersion7 {
		mixin(GenDataModel!("UnittestUser", `
			int uid;
			int d_created;
			int d_modified;
			string firstname;
			string middlename;
			string lastname;
		`));
	}
	
	static assert(UserDataModelVersion7.Data.sizeof == (long.sizeof + int.sizeof*3 + string.sizeof*3));
	
	class UserDataModelVersion8 {
		mixin(GenDataModel!("UnittestUser", `
			int uid;
			int d_modified;
			string firstname;
			string middlename;
			string lastname;
		`));
	}
	
	static assert(UserDataModelVersion8.Data.sizeof == (long.sizeof + int.sizeof*2 + string.sizeof*3));
	
	class UserDataModelVersion9 {
		mixin(GenDataModel!("UnittestUser", `
			string lastname;
			int d_modified;
			string firstname;
			int uid;
			string middlename;
		`));
	}
	
	static assert(UserDataModelVersion9.Data.sizeof == (long.sizeof + int.sizeof*2 + string.sizeof*3));
	
	class UnittestPhotoTag : TemplateObject {
		mixin(GenDataModel!("UnittestPhotoTag", `
			int pid;
			int uid;
			int d_created;
			float xpos;
			float ypos;
			string comment;
		`, true));
		
		void register(PNL* pnl, inout string[string] params) {
			// do nothing...
		}
	}

	class Test_Edb : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		
		void prepare() {
			mongo_cmd_drop_collection(conn, "test", "UnittestUser", null);
			mongo_cmd_drop_collection(conn, "test", "UnittestPhotoTag", null);
			reset_state();
		}
		
		void clean() {
			mongo_cmd_drop_collection(conn, "test", "UnittestUser", null);
			mongo_cmd_drop_collection(conn, "test", "UnittestPhotoTag", null);
			reset_state();
		}
		
		void test() {
			//versioning();
			insert();
			looping();
			
			reset_state();
			template1();
			
			reset_state();
			template2();
			
			reset_state();
			template3();
			
			reset_state();
			template4();
			
			reset_state();
			template5();
			
			reset_state();
			template6();
			
			reset_state();
			template7();
			
			reset_state();
			template8();
			
			reset_state();
			template9();
			
			//reset_state();
			//template10();
		}
		
		void versioning() {
			UserDataModelVersion1 u1 = new UserDataModelVersion1(0);
			u1._id = -11; // a negative number means it's a new obj
			u1.save();
			u1.data.uid = 11;
			u1.data.firstname = "kenny";
			u1.data.lastname = "danger";
			u1.save();
			
			// obj gets loaded correctly
			UserDataModelVersion1 u11 = new UserDataModelVersion1(11);
			assert(u11._id == 11);
			assert(u11.data.uid == 11);
			assert(u11.uid == 11);
			assert(u11.data.firstname == "kenny");
			assert(u11.firstname == "kenny");
			assert(u11.data.lastname == "danger");
			assert(u11.lastname == "danger");
			
			// obj comes from cache correctly
			UserDataModelVersion1 u12 = new UserDataModelVersion1(11);
			assert(u12._id == 11);
			assert(u12.uid == 11);
			assert(u12.firstname == "kenny");
			assert(u12.lastname == "danger");
			UserDataModelVersion1.cache = null; // it won't save if there are no changes
			u12.save();
			
			// add a field between firstname and lastname
			UserDataModelVersion2 u2 = new UserDataModelVersion2(11);
			assert(u2._id == 11);
			assert(u2.uid == 11);
			assert(u2.firstname == "kenny");
			assert(u2.newfield == "");
			assert(u2.lastname == "danger");
			UserDataModelVersion2.cache = null; // it won't save if there are no changes
			u2.save();
			
			// remove the field between firstname and lastname
			UserDataModelVersion3 u3 = new UserDataModelVersion3(11);
			assert(u3._id == 11);
			assert(u3.uid == 11);
			assert(u3.firstname == "kenny");
			assert(u3.lastname == "danger");
			UserDataModelVersion3.cache = null; // it won't save if there are no changes
			u3.save();
			
			UserDataModelVersion4 u4 = new UserDataModelVersion4(11);
			assert(u4._id == 11);
			assert(u4.uid == 11);
			assert(u4.firstname == "kenny");
			assert(u4.lastname == "danger");
			UserDataModelVersion4.cache = null; // it won't save if there are no changes
			u4.save();
			
			// let's test now, the ability to upgrade schemas
			
			// save a version 1
			UserDataModelVersion1.cache = null;
			UserDataModelVersion3.cache = null;
			u1.save();
			
			// now, load a version 3
			u3 = new UserDataModelVersion3(11);
			assert(u3._id == 11);
			assert(u3.uid == 11);
			assert(u3.firstname == "kenny");
			assert(u3.lastname == "danger");
			
			// save a version 1
			//UserDataModelVersion1.cache = null;
			UserDataModelVersion1.cache = null;
			UserDataModelVersion4.cache = null;
			u1.save();
			
			// now, load a version 4
			u4 = new UserDataModelVersion4(11);
			assert(u4._id == 11);
			assert(u4.uid == 11);
			assert(u4.firstname == "kenny");
			assert(u4.lastname == "danger");
			
			// save a version 1
			UserDataModelVersion1.cache = null;
			UserDataModelVersion5.cache = null;
			u1.save();
			
			// now, load a version 5
			UserDataModelVersion5 u5 = new UserDataModelVersion5(11);
			assert(u5._id == 11);
			assert(u5.uid == 11);
			assert(u5.firstname == "kenny");
			assert(u5.lastname == "danger");
			
			// save a version 1
			UserDataModelVersion1.cache = null;
			UserDataModelVersion6.cache = null;
			u1.save();
			
			// now, load a version 5
			u5 = new UserDataModelVersion5(11);
			assert(u5._id == 11);
			assert(u5.uid == 11);
			assert(u5.firstname == "kenny");
			assert(u5.lastname == "danger");
			
			// save a version 1
			UserDataModelVersion1.cache = null;
			UserDataModelVersion6.cache = null;
			u1.save();
			
			// now, load a version 6
			UserDataModelVersion6 u6 = new UserDataModelVersion6(11);
			assert(u6._id == 11);
			assert(u6.uid == 11);
			assert(u6.firstname == "kenny");
			assert(u6.lastname == "danger");
			
			// save a version 1
			UserDataModelVersion1.cache = null;
			UserDataModelVersion7.cache = null;
			u1.save();
			
			// now, load a version 7
			UserDataModelVersion7 u7 = new UserDataModelVersion7(11);
			assert(u7._id == 11);
			assert(u7.uid == 11);
			assert(u7.firstname == "kenny");
			assert(u7.lastname == "danger");
			
			// save a version 1
			UserDataModelVersion1.cache = null;
			UserDataModelVersion7.cache = null;
			u1.save();
			
			// now, load a version 8
			UserDataModelVersion8 u8 = new UserDataModelVersion8(11);
			assert(u8._id == 11);
			assert(u8.uid == 11);
			assert(u8.firstname == "kenny");
			assert(u8.lastname == "danger");
			
			// now, load a version 9
			UserDataModelVersion9 u9 = new UserDataModelVersion9(11);
			assert(u8._id == 11);
			assert(u8.uid == 11);
			assert(u8.firstname == "kenny");
			assert(u8.lastname == "danger");
			u9.destroy();
		}
		
		void insert() {
			// generate a few photo tags for testing indexes
			//UnittestPhotoTag pt0 = new UnittestPhotoTag();
			
			//assert(UnittestPhotoTag.total("$orderby: {d_created: 1}") == 0);
			
			UnittestPhotoTag pt = new UnittestPhotoTag(0);
			//assert(pt.total("") == 0);
			pt._id = -1; // a negative number means it's a new obj
			pt.uid = 11;
			pt.pid = 1;
			pt.d_created = 1000;
			pt.xpos = 0.5;
			pt.ypos = 0.75;
			pt.comment = "picture 1";
			pt.save();
			
			assert(pt.total("") == 1);
			assert(pt.total("_id: 1") == 1);
			assert(pt.total("_id: 2") == 0);
			assert(pt.total("_id: 3") == 0);
			assert(pt.total("uid: 11") == 1);
			
			pt._id = -2;
			pt.uid = 1058;
			pt.pid = 2;
			pt.d_created = 1100; // append end
			pt.xpos = 0.5;
			pt.ypos = 0.75;
			pt.comment = "picture 2";
			pt.save();
			
			assert(pt.total("") == 2);
			assert(pt.total("_id: 1") == 1);
			assert(pt.total("_id: 2") == 1);
			assert(pt.total("_id: 3") == 0);
			assert(pt.total("uid: 11") == 1);
			
			pt._id = -3;
			pt.uid = 11;
			pt.pid = 2;
			pt.d_created = 1100; // append end
			pt.xpos = 0.5;
			pt.ypos = 0.75;
			pt.comment = "picture 2";
			pt.save();
			
			assert(pt.total("") == 3);
			assert(pt.total("_id: 1") == 1);
			assert(pt.total("_id: 2") == 1);
			assert(pt.total("_id: 3") == 1);
			assert(pt.total("uid: 11") == 2);
		}
		
		void looping() {
			// find only one
			UnittestPhotoTag ptags = new UnittestPhotoTag("", 0, 1);
			assert(ptags._id == 1);
			assert(ptags.uid == 11);
			assert(!ptags.loop());
			
			/*
			// find two by modifying the variable via the query
			ptags = new UnittestPhotoTag("$page_size: 2");
			assert(ptags._id == 1);
			assert(ptags.uid == 11);
			assert(ptags.loop());
			assert(ptags._id == 2);
			assert(ptags.uid == 1058);
			assert(!ptags.loop());
			
			ptags = new UnittestPhotoTag("$orderby: {_id: -1}, $page_size: 2");
			assert(ptags._id == 3);
			assert(ptags.uid == 11);
			assert(ptags.loop());
			assert(ptags._id == 2);
			assert(ptags.uid == 1058);
			assert(!ptags.loop());
			
			ptags = new UnittestPhotoTag("$orderby: {_id: -1}, uid: 11, $page_size: 2");
			assert(ptags._id == 3);
			assert(ptags.uid == 11);
			assert(ptags.loop());
			assert(ptags._id == 1);
			assert(ptags.uid == 11);
			assert(!ptags.loop());
			
			/*
			ptags = new UnittestPhotoTag(`$orderby: {_id: -1}, comment: "picture 2", $page_size: 2`);
			assert(ptags._id == 3);
			assert(ptags.uid == 11);
			assert(ptags.loop());
			assert(ptags._id == 2);
			assert(ptags.uid == 1058);
			assert(!ptags.loop());
			
			/*
			assert(PhotoTags.list.length == 1);
			assert(PhotoTags_d_created.list.length == 1);
			o = PhotoTags_d_created.list[0];
			assert(o._id == 1);
			assert(o.order == 1000);
			o = UserPhotoTags_d_created.list(11)[0];
			assert(o._id == 1);
			assert(o.order == 1000);
			
			pt0._id = -2;
			pt0.uid = 1058;
			pt0.pid = 2;
			pt0.d_created = 1100; // append end
			pt0.xpos = 0.5;
			pt0.ypos = 0.75;
			pt0.save();
			
			assert(PhotoTags.list.length == 2);
			assert(PhotoTags_d_created.list.length == 2);
			assert(UserPhotoTags.list(11).length == 1);
			assert(UserPhotoTags_d_created.list(11).length == 1);
			assert(UserPhotoTags.list(1058).length == 1);
			assert(UserPhotoTags_d_created.list(1058).length == 1);
			o = PhotoTags_d_created.list[0];
			assert(o._id == 2);
			assert(o.order == 1100);
			o = UserPhotoTags_d_created.list(1058)[0];
			assert(o._id == 2);
			assert(o.order == 1100);
			
			pt0._id = -3;
			pt0.uid = 11;
			pt0.pid = 2;
			pt0.d_created = 900; // append beginning
			pt0.xpos = 0.5;
			pt0.ypos = 0.75;
			pt0.save();
			
			assert(PhotoTags.list.length == 3);
			assert(PhotoTags_d_created.list.length == 3);
			assert(UserPhotoTags.list(11).length == 2);
			assert(UserPhotoTags_d_created.list(11).length == 2);
			assert(UserPhotoTags.list(1058).length == 1);
			assert(UserPhotoTags_d_created.list(1058).length == 1);
			o = PhotoTags_d_created.list[2];
			assert(o._id == 3);
			assert(o.order == 900);
			o = UserPhotoTags_d_created.list(11)[1];
			assert(o._id == 3);
			assert(o.order == 900);
			
			UnittestPhotoTag pt1 = new UnittestPhotoTag(1);
			
			assert(pt1._id == 1);
			assert(pt1.uid == 11);
			assert(pt1.pid == 1);
			assert(pt1.xpos == 0.5);
			assert(pt1.ypos == 0.75);
			assert(PhotoTags.list.length == 3);
			assert(PhotoTags_d_created.list.length == 3);
			
			UnittestPhotoTag pt2 = new UnittestPhotoTag(2);
			
			assert(pt2._id == 2);
			assert(pt2.uid == 1058);
			assert(pt2.pid == 2);
			assert(pt2.xpos == 0.5);
			assert(pt2.ypos == 0.75);
			assert(PhotoTags.list.length == 3);
			assert(PhotoTags_d_created.list.length == 3);
			
			
			UnittestPhotoTag pt3 = new UnittestPhotoTag(3);
			
			assert(pt3._id == 3);
			assert(pt3.uid == 11);
			assert(pt3.pid == 2);
			assert(pt3.xpos == 0.5);
			assert(pt3.ypos == 0.75);
			assert(PhotoTags.list.length == 3);
			assert(PhotoTags_d_created.list.length == 3);
			assert(UserPhotoTags.list(11).length == 2);
			assert(UserPhotoTags.list(1058).length == 1);
			assert(PhotoPhotoTags.list(1).length == 1);
			assert(PhotoPhotoTags.list(2).length == 2);
			assert(UserPhotoTags_d_created.list(11).length == 2);
			assert(UserPhotoTags_d_created.list(1058).length == 1);
			assert(PhotoPhotoTags_d_created.list(1).length == 1);
			assert(PhotoPhotoTags_d_created.list(2).length == 2);
			
			UnittestPhotoTag pt4 = new UnittestPhotoTag(0);
			pt4._id = -4;
			pt4.uid = 11;
			pt4.pid = 3;
			pt4.d_created = 950; // append middle
			pt4.xpos = 0.5;
			pt4.ypos = 0.75;
			pt4.save();
			
			assert(PhotoTags.list.length == 4);
			assert(PhotoTags_d_created.list.length == 4);
			assert(UserPhotoTags.list(11).length == 3);
			assert(PhotoPhotoTags.list(3).length == 1);
			assert(UserPhotoTags_d_created.list(11).length == 3);
			assert(PhotoPhotoTags_d_created.list(3).length == 1);
			o = PhotoTags_d_created.list[2];
			assert(o._id == 4);
			assert(o.order == 950);
			o = PhotoTags_d_created.list[3];
			assert(o._id == 3);
			assert(o.order == 900);
			o = UserPhotoTags_d_created.list(11)[1];
			assert(o._id == 4);
			assert(o.order == 950);
			
			
			UnittestPhotoTag pt5 = new UnittestPhotoTag(0);
			pt5._id = -5;
			pt5.uid = 26;
			pt5.pid = 3;
			pt5.d_created = 951; // append middle
			pt5.xpos = 0.5;
			pt5.ypos = 0.75;
			pt5.save();
			
			assert(PhotoTags.list.length == 5);
			assert(PhotoTags_d_created.list.length == 5);
			assert(UserPhotoTags.list(26).length == 1);
			assert(PhotoPhotoTags.list(3).length == 2);
			assert(UserPhotoTags_d_created.list(26).length == 1);
			assert(PhotoPhotoTags_d_created.list(3).length == 2);
			o = PhotoTags_d_created.list[2];
			assert(o._id == 5);
			assert(o.order == 951);
			o = PhotoTags_d_created.list[3];
			assert(o._id == 4);
			assert(o.order == 950);
			
			pt5.d_created = 949; // move the entry in the index
			assert(pt5.data.d_created == 949);
			pt5.save();
			
			o = PhotoTags_d_created.list[3];
			assert(o._id == 5);
			assert(o.order == 949);
			o = PhotoTags_d_created.list[2];
			assert(o._id == 4);
			assert(o.order == 950);
			
			pt5.destroy();
			
			pt5 = new UnittestPhotoTag(5);
			assert(pt5._id == -5);
			
			assert(PhotoTags.list.length == 4);
			assert(PhotoTags_d_created.list.length == 4);
			assert(UserPhotoTags.list(26).length == 0);
			assert(PhotoPhotoTags.list(3).length == 1);
			assert(UserPhotoTags_d_created.list(26).length == 0);
			assert(PhotoPhotoTags_d_created.list(3).length == 1);
			o = PhotoTags_d_created.list[1];
			assert(o._id == 1);
			assert(o.order == 1000);
			o = PhotoTags_d_created.list[2];
			assert(o._id == 4);
			assert(o.order == 950);
			
			pt3.destroy();
			
			assert(PhotoTags.list.length == 3);
			assert(PhotoTags_d_created.list.length == 3);
			assert(UserPhotoTags.list(11).length == 2);
			assert(UserPhotoTags_d_created.list(11).length == 2);
			o = PhotoTags_d_created.list[2];
			assert(o._id == 4);
			assert(o.order == 950);
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1111;
			pt0.uid = 1;
			pt0.save();
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1111;
			pt0.uid = 2;
			pt0.save();
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1111;
			pt0.uid = 3;
			pt0.save();
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1111;
			pt0.uid = 4;
			pt0.save();
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1111;
			pt0.uid = 5;
			pt0.save();
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1155;
			pt0.uid = 1;
			pt0.save();
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1155;
			pt0.uid = 2;
			pt0.save();
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1155;
			pt0.uid = 3;
			pt0.save();
			
			pt0 = new UnittestPhotoTag(0);
			pt0.pid = 1155;
			pt0.uid = 1;
			pt0.save();
			
			assert(PhotoPhotoTags.list(1111).length == 5);
			assert(PhotoPhotoTags.list(1155).length == 4);
			*/
		}
		
		void template1() {
			PNL.parse_text(`
				<?interface panel:'edb1' ?>
				<?load UnittestPhotoTag {_id: 1} ?>
				_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>
			`);
			
			assert("edb1" in PNL.pnl);
			PNL.pnl["edb1"].render();
			
			assert(out_tmp[0 .. out_ptr] == `_id:1,uid:11,d_created:1000`);
		}
		
		void template2() {
			PNL.parse_text(`
				<?interface panel:'edb2' ?>
				<?load UnittestPhotoTag {uid: 11, $page_size: 1} ?>
				_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>
			`);
			
			assert("edb2" in PNL.pnl);
			PNL.pnl["edb2"].render();
			
			assert(out_tmp[0 .. out_ptr] == `_id:1,uid:11,d_created:1000`);
		}
		
		void template3() {
			PNL.parse_text(`
				<?interface panel:'edb3' ?>
				<?loop UnittestPhotoTag {uid: 11, $page_size: 1} ?>
					_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>,
				<?endloop?>
			`);
			
			assert("edb3" in PNL.pnl);
			PNL.pnl["edb3"].render();
			
			assert(out_tmp[0 .. out_ptr] == `_id:1,uid:11,d_created:1000,`);
		}
		
		void template4() {
			PNL.parse_text(`
				<?interface panel:'edb4' ?>
				<?loop UnittestPhotoTag {uid: 11, $page_size: 2, $orderby: {d_created: 1}} ?>
					_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>,
				<?endloop?>
			`);
			
			assert("edb4" in PNL.pnl);
			PNL.pnl["edb4"].render();
			
			assert(out_tmp[0 .. out_ptr] == `_id:1,uid:11,d_created:1000,_id:3,uid:11,d_created:1100,`);
		}
		
		void template5() {
			PNL.parse_text(`
				<?interface panel:'edb5' ?>
				<?loop UnittestPhotoTag {uid: 11, $page_size: 2, $orderby: {d_created: -1}} ?>
					_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>,
				<?endloop?>
			`);
			
			assert("edb5" in PNL.pnl);
			PNL.pnl["edb5"].render();
			
			assert(out_tmp[0 .. out_ptr] == `_id:3,uid:11,d_created:1100,_id:1,uid:11,d_created:1000,`);
		}
		
		void template6() {
			PNL.parse_text(`
				<?interface panel:'edb6' ?>
				<?load Url {uid: int} ?>
				(<?=Url.uid?>)
				<?loop UnittestPhotoTag {uid: $Url.uid, $page_size: 2, $orderby: {d_created: -1}} ?>
					_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>,
				<?endloop?>
			`);
			
			assert("edb6" in PNL.pnl);
			POST["uid"] = "11";
			PNL.pnl["edb6"].render();
			assert(out_tmp[0 .. out_ptr] == `(11)_id:3,uid:11,d_created:1100,_id:1,uid:11,d_created:1000,`);
			
			out_ptr = 0;
			
			POST["uid"] = "1058";
			PNL.pnl["edb6"].render();
			assert(out_tmp[0 .. out_ptr] == `(1058)_id:2,uid:1058,d_created:1100,`);
			
			out_ptr = 0;
			
			POST["uid"] = "1111";
			PNL.pnl["edb6"].render();
			assert(out_tmp[0 .. out_ptr] == `(1111)`);
		}
		
		void template7() {
			PNL.parse_text(`
				<?interface panel:'edb7' ?>
				<?load Url {pic: string} ?>
				(<?=Url.pic?>)
				<?loop UnittestPhotoTag {comment: $Url.pic, $page_size: 2, $orderby: {uid: 1}} ?>
					_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>,
				<?endloop?>
			`);
			
			assert("edb7" in PNL.pnl);
			POST["pic"] = "picture 1";
			PNL.pnl["edb7"].render();
			assert(out_tmp[0 .. out_ptr] == `(picture 1)_id:1,uid:11,d_created:1000,`);
			
			out_ptr = 0;
			
			POST["pic"] = "picture 2";
			PNL.pnl["edb7"].render();
			assert(out_tmp[0 .. out_ptr] == `(picture 2)_id:3,uid:11,d_created:1100,_id:2,uid:1058,d_created:1100,`);
			
			out_ptr = 0;
			
			POST["pic"] = "no picture";
			PNL.pnl["edb7"].render();
			assert(out_tmp[0 .. out_ptr] == `(no picture)`);
		}
		
		void template8() {
			PNL.parse_text(`
				<?interface panel:'edb8' ?>
				<?load UnittestPhotoTag ?>
				total:<?=UnittestPhotoTag.total {uid: 11} ?>
			`);
			
			assert("edb8" in PNL.pnl);
			PNL.pnl["edb8"].render();
			assert(out_tmp[0 .. out_ptr] == `total:2`);
		}
		
		void template8_1() {
			//TODO!!! - make the functions global
			PNL.parse_text(`
				<?interface panel:'edb8_1' ?>
				total:<?=UnittestPhotoTag.total {uid: 11} ?>
			`);
			
			assert("edb8_1" in PNL.pnl);
			PNL.pnl["edb8_1"].render();
			assert(out_tmp[0 .. out_ptr] == `total:2`);
		}
		
		void template9() {
			PNL.parse_text(`
				<?interface panel:'edb9' ?>
				<?load UnittestPhotoTag {uid: 11, $page_size: 1} ?>
				(<?=UnittestPhotoTag.total {uid: 11, $page_size: 1} ?>)
				_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>
			`);
			
			assert("edb9" in PNL.pnl);
			PNL.pnl["edb9"].render();
			
			assert(out_tmp[0 .. out_ptr] == `(2)_id:1,uid:11,d_created:1000`);
		}
		
		void template10() {
			//TODO!!! - make the functions global!!!
			PNL.parse_text(`
				<?interface panel:'edb10' ?>
				<?load Url {pic: string} ?>
				(<?=Url.pic?>:<?=UnittestPhotoTag.total {comment: $Url.pic }?>)
				<?loop UnittestPhotoTag {comment: $Url.pic, $page_size: 2, $orderby: {uid: 1}} ?>
					_id:<?=UnittestPhotoTag._id%>,uid:<?=UnittestPhotoTag.uid?>,d_created:<?=UnittestPhotoTag.d_created?>,
				<?endloop?>
			`);
			
			assert("edb10" in PNL.pnl);
			POST["pic"] = "picture 1";
			PNL.pnl["edb10"].render();
			assert(out_tmp[0 .. out_ptr] == `(picture 1:1)_id:1,uid:11,d_created:1000,`);
			out_ptr = 0;
			
			POST["pic"] = "picture 2";
			PNL.pnl["edb10"].render();
			assert(out_tmp[0 .. out_ptr] == `(picture 2:2)_id:3,uid:11,d_created:1100,_id:2,uid:1058,d_created:1100,`);
		}
	}
	
	
	/*
	UNIT("file access", () {
		uint[] vars;
		vars ~= 1;
		File.set("UNITTEST", cast(void[]) vars);
		assert(File.get("UNITTEST") == vars);
		vars ~= 2;
		File.append("UNITTEST", cast(void[]) vars[$-1 .. $]);
		assert(File.get("UNITTEST") == vars);
		vars ~= 3;
		File.append("UNITTEST", cast(void[]) vars[$-1 .. $]);
		assert(File.get("UNITTEST") == vars);
		vars ~= 4;
		File.append("UNITTEST", cast(void[]) vars[$-1 .. $]);
		assert(File.get("UNITTEST") == vars);
		vars ~= 5;
		File.append("UNITTEST", cast(void[]) vars[$-1 .. $]);
		assert(File.get("UNITTEST") == vars);
		vars ~= 6;
		File.append("UNITTEST", cast(void[]) vars[$-1 .. $]);
		assert(File.get("UNITTEST") == vars);
		vars ~= 7;
		File.append("UNITTEST", cast(void[]) vars[$-1 .. $]);
		assert(File.get("UNITTEST") == vars);
		Path.remove("UNITTEST");
	});
	*/
}


/+
unittest {
	class UnittestPhotoTag {
		mixin(GenDataModel!("UnittestPhotoTag", "
			int pid;
			int uid;
			int d_created;
			float xpos;
			float ypos;
			"));
	}
	
	static assert(UnittestPhotoTag.Data.sizeof == (int.sizeof*5));
	
	class PhotoTags {
		mixin(IndexTableUnordered!("UnittestPhotoTags", "UnittestPhotoTag", true));
	}
	
	class PhotoTags_d_created {
		mixin(IndexTableOrdered!("UnittestPhotoTags", "UnittestPhotoTag", "d_created", true));
	}
	
	class UserPhotoTags {
		mixin(IndexKeyUnordered!("UnittestPhotoTag", "uid", "UnittestPhotoTag", true));
	}
	
	class PhotoPhotoTags {
		mixin(IndexKeyUnordered!("UnittestPhotoTag", "pid", "UnittestPhotoTag", true));
	}
	
	class UserPhotoTags_d_created {
		mixin(IndexKeyOrdered!("UnittestPhotoTag", "uid", "UnittestPhotoTag", "d_created", true));
	}
	
	class PhotoPhotoTags_d_created {
		mixin(IndexKeyOrdered!("UnittestPhotoTag", "pid", "UnittestPhotoTag", "d_created", true));
	}

	
	assert(!Path.exists("edb/UnittestPhotoTag/#1"));
	
	// have to manually initialze them
	UnittestPhotoTag.edb_init();
	PhotoTags.edb_init();
	PhotoTags_d_created.edb_init();
	UserPhotoTags.edb_init();
	PhotoPhotoTags.edb_init();
	UserPhotoTags_d_created.edb_init();
	PhotoPhotoTags_d_created.edb_init();
	
	// just in case
	PhotoPhotoTags.cache = null;
	UserPhotoTags.cache = null;
	cache = null;
	ordered o;
	
	// generate a few photo tags for testing indexes
	assert(PhotoTags.list.length == 0);
	assert(PhotoTags_d_created.list.length == 0);
	UnittestPhotoTag pt0 = new UnittestPhotoTag(0);
	pt0.id = -1; // a negative number means it's a new obj
	pt0.uid = 11;
	pt0.pid = 1;
	pt0.d_created = 1000;
	pt0.xpos = 0.5;
	pt0.ypos = 0.75;
	pt0.save();
	
	assert(PhotoTags.list.length == 1);
	assert(PhotoTags_d_created.list.length == 1);
	o = PhotoTags_d_created.list[0];
	assert(o.id == 1);
	assert(o.order == 1000);
	o = UserPhotoTags_d_created.list(11)[0];
	assert(o.id == 1);
	assert(o.order == 1000);
	
	pt0.id = -2;
	pt0.uid = 1058;
	pt0.pid = 2;
	pt0.d_created = 1100; // append end
	pt0.xpos = 0.5;
	pt0.ypos = 0.75;
	pt0.save();
	
	assert(PhotoTags.list.length == 2);
	assert(PhotoTags_d_created.list.length == 2);
	assert(UserPhotoTags.list(11).length == 1);
	assert(UserPhotoTags_d_created.list(11).length == 1);
	assert(UserPhotoTags.list(1058).length == 1);
	assert(UserPhotoTags_d_created.list(1058).length == 1);
	o = PhotoTags_d_created.list[0];
	assert(o.id == 2);
	assert(o.order == 1100);
	o = UserPhotoTags_d_created.list(1058)[0];
	assert(o.id == 2);
	assert(o.order == 1100);
	
	pt0.id = -3;
	pt0.uid = 11;
	pt0.pid = 2;
	pt0.d_created = 900; // append beginning
	pt0.xpos = 0.5;
	pt0.ypos = 0.75;
	pt0.save();
	
	assert(PhotoTags.list.length == 3);
	assert(PhotoTags_d_created.list.length == 3);
	assert(UserPhotoTags.list(11).length == 2);
	assert(UserPhotoTags_d_created.list(11).length == 2);
	assert(UserPhotoTags.list(1058).length == 1);
	assert(UserPhotoTags_d_created.list(1058).length == 1);
	o = PhotoTags_d_created.list[2];
	assert(o.id == 3);
	assert(o.order == 900);
	o = UserPhotoTags_d_created.list(11)[1];
	assert(o.id == 3);
	assert(o.order == 900);
	
	UnittestPhotoTag pt1 = new UnittestPhotoTag(1);
	
	assert(pt1.id == 1);
	assert(pt1.uid == 11);
	assert(pt1.pid == 1);
	assert(pt1.xpos == 0.5);
	assert(pt1.ypos == 0.75);
	assert(PhotoTags.list.length == 3);
	assert(PhotoTags_d_created.list.length == 3);
	
	UnittestPhotoTag pt2 = new UnittestPhotoTag(2);
	
	assert(pt2.id == 2);
	assert(pt2.uid == 1058);
	assert(pt2.pid == 2);
	assert(pt2.xpos == 0.5);
	assert(pt2.ypos == 0.75);
	assert(PhotoTags.list.length == 3);
	assert(PhotoTags_d_created.list.length == 3);
	
	
	UnittestPhotoTag pt3 = new UnittestPhotoTag(3);
	
	assert(pt3.id == 3);
	assert(pt3.uid == 11);
	assert(pt3.pid == 2);
	assert(pt3.xpos == 0.5);
	assert(pt3.ypos == 0.75);
	assert(PhotoTags.list.length == 3);
	assert(PhotoTags_d_created.list.length == 3);
	assert(UserPhotoTags.list(11).length == 2);
	assert(UserPhotoTags.list(1058).length == 1);
	assert(PhotoPhotoTags.list(1).length == 1);
	assert(PhotoPhotoTags.list(2).length == 2);
	assert(UserPhotoTags_d_created.list(11).length == 2);
	assert(UserPhotoTags_d_created.list(1058).length == 1);
	assert(PhotoPhotoTags_d_created.list(1).length == 1);
	assert(PhotoPhotoTags_d_created.list(2).length == 2);
	
	UnittestPhotoTag pt4 = new UnittestPhotoTag(0);
	pt4.id = -4;
	pt4.uid = 11;
	pt4.pid = 3;
	pt4.d_created = 950; // append middle
	pt4.xpos = 0.5;
	pt4.ypos = 0.75;
	pt4.save();
	
	assert(PhotoTags.list.length == 4);
	assert(PhotoTags_d_created.list.length == 4);
	assert(UserPhotoTags.list(11).length == 3);
	assert(PhotoPhotoTags.list(3).length == 1);
	assert(UserPhotoTags_d_created.list(11).length == 3);
	assert(PhotoPhotoTags_d_created.list(3).length == 1);
	o = PhotoTags_d_created.list[2];
	assert(o.id == 4);
	assert(o.order == 950);
	o = PhotoTags_d_created.list[3];
	assert(o.id == 3);
	assert(o.order == 900);
	o = UserPhotoTags_d_created.list(11)[1];
	assert(o.id == 4);
	assert(o.order == 950);
	
	
	UnittestPhotoTag pt5 = new UnittestPhotoTag(0);
	pt5.id = -5;
	pt5.uid = 26;
	pt5.pid = 3;
	pt5.d_created = 951; // append middle
	pt5.xpos = 0.5;
	pt5.ypos = 0.75;
	pt5.save();
	
	assert(PhotoTags.list.length == 5);
	assert(PhotoTags_d_created.list.length == 5);
	assert(UserPhotoTags.list(26).length == 1);
	assert(PhotoPhotoTags.list(3).length == 2);
	assert(UserPhotoTags_d_created.list(26).length == 1);
	assert(PhotoPhotoTags_d_created.list(3).length == 2);
	o = PhotoTags_d_created.list[2];
	assert(o.id == 5);
	assert(o.order == 951);
	o = PhotoTags_d_created.list[3];
	assert(o.id == 4);
	assert(o.order == 950);
	
	pt5.d_created = 949; // move the entry in the index
	assert(pt5.data.d_created == 949);
	pt5.save();
	
	o = PhotoTags_d_created.list[3];
	assert(o.id == 5);
	assert(o.order == 949);
	o = PhotoTags_d_created.list[2];
	assert(o.id == 4);
	assert(o.order == 950);
	
	pt5.destroy();
	
	pt5 = new UnittestPhotoTag(5);
	assert(pt5.id == -5);
	
	assert(PhotoTags.list.length == 4);
	assert(PhotoTags_d_created.list.length == 4);
	assert(UserPhotoTags.list(26).length == 0);
	assert(PhotoPhotoTags.list(3).length == 1);
	assert(UserPhotoTags_d_created.list(26).length == 0);
	assert(PhotoPhotoTags_d_created.list(3).length == 1);
	o = PhotoTags_d_created.list[1];
	assert(o.id == 1);
	assert(o.order == 1000);
	o = PhotoTags_d_created.list[2];
	assert(o.id == 4);
	assert(o.order == 950);
	
	pt3.destroy();
	
	assert(PhotoTags.list.length == 3);
	assert(PhotoTags_d_created.list.length == 3);
	assert(UserPhotoTags.list(11).length == 2);
	assert(UserPhotoTags_d_created.list(11).length == 2);
	o = PhotoTags_d_created.list[2];
	assert(o.id == 4);
	assert(o.order == 950);
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1111;
	pt0.uid = 1;
	pt0.save();
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1111;
	pt0.uid = 2;
	pt0.save();
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1111;
	pt0.uid = 3;
	pt0.save();
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1111;
	pt0.uid = 4;
	pt0.save();
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1111;
	pt0.uid = 5;
	pt0.save();
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1155;
	pt0.uid = 1;
	pt0.save();
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1155;
	pt0.uid = 2;
	pt0.save();
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1155;
	pt0.uid = 3;
	pt0.save();
	
	pt0 = new UnittestPhotoTag(0);
	pt0.pid = 1155;
	pt0.uid = 1;
	pt0.save();
	
	assert(PhotoPhotoTags.list(1111).length == 5);
	assert(PhotoPhotoTags.list(1155).length == 4);
	
	cache = null;
	exec("rm -rf " ~ data_dir ~ "/Unittest*");
	exec("rm -rf " ~ index_dir ~ "/Unittest*");
	exec("rm -rf " ~ model_dir ~ "/Unittest*");
}
+/

