module session;

import tango.stdc.stdlib;
import Integer = tango.text.convert.Integer;

import lib;
import shared;
import edb;
import panel;


class UserAuth : EdbObject {
	mixin(GenDataModel!("UserAuth", `
		uint email_crc;
		int uid;
		string email;
		string password;
	`));
	
	static this() {
		PNL.exportFunction("logout", &func_logout);
	
		PNL.exportPublicFunction("login", &func_login);
		PNL.exportFunctionArg("login", "email");
		PNL.exportFunctionArg("login", "password");
		PNL.exportFunctionArg("login", "sess_len");
	}
	
	static int validate_user(string email, string passwd) {
		//uint[] users = UserAuth.query(crc32(0, cast(ubyte*)email.ptr, email.length));
		UserAuth ua = new UserAuth("email_crc:" ~ Integer.toString(crc32(0, cast(ubyte*)email.ptr, email.length)));
		//UserAuth.query(crc32(0, cast(ubyte*)email.ptr, email.length));
		//foreach(i; users) {
		while(ua.loop()) {
			//ua = new UserAuth(i);
			if(ua.email == email) {
				if(ua.password == passwd) {
					return ua.uid;
				} else {
					return FAILURE;
				}
			}
		}
		
		return HACKING;
	}
	
	static int func_login() {
		string* ptr_email = "email" in FUNC;
		string* ptr_passwd = "password" in FUNC;
		string* ptr_sesslen = "sess_len" in FUNC;
		if(ptr_email && ptr_passwd && ptr_sesslen) {
			//TODO!!! - do a check to validate that it's a good email.
			return login(*ptr_email, *ptr_passwd, toUint(*ptr_sesslen));
		}
		
		return HACKING;
	}
	
	static int login(string email, string passwd, uint session_length) {
		int auth_uid = UserAuth.validate_user(email, passwd);
		if(auth_uid > 0) {
			if(cur_session is null) {
				cur_conn.make_session();
				.cur_session = cur_conn.session;
			}
			
			//assert(session == cur_conn.session); // this means that session !is null
			cur_session.online = 1;
			cur_session.uid = .uid = auth_uid;
			cur_session.last_request = request_time;
			session_length *= 60;
			cur_session.expire_time = (session_length ? session_length : 30*60);
			user_session = new UserSession(.uid);
			if(user_session._id < 0) {
				user_session.last_request = request_time;
			}
			
			user_session.hits++;
			cur_session.time_delta = user_session.last_request;
			// save???
		}
		
		return auth_uid;
	}
	
	static int func_logout() {
		cur_session.online = 0;
		cur_session.save();
		.uid = 0;
		return SUCCESS;
	}

}


class Session : EdbObject {
	// OPTIMIZE!! - later, store the language as a short instead of a string
	mixin(GenDataModel!("Session", `
		string sid; // make an index across these for fast lookups.
		uint sidb;
		
		int d_begin;
		int d_last_request;
		
		int uid; // logged in > 0
		int hits;
		int page_hits;
		
		int last_request;
		int expire_time;
		int time_delta;
		int timezone;
		
		string lang;
		int online;
	`));
	
	static this() {
		PNL.exportPublicFunction("tz", &func_set_timezone); // untested
		PNL.exportFunctionArg("tz", "tz");
	}
	
	private static string get_rand_sid() {
		char[26] output = '0';
		string tmp;
		
		tmp = enc_int(rand());
		
		output[0 .. tmp.length] = tmp;
		
		tmp = enc_int(rand());
		output[6 .. 6+tmp.length] = tmp;
		
		tmp = enc_int(rand());
		output[12 .. 12+tmp.length] = tmp;
		
		tmp = enc_int(rand());
		output[18 .. 18+tmp.length] = tmp;
		
		tmp = enc_int(rand());
		if(tmp.length > 2) {
			tmp.length = 2;
		}
		
		output[24 .. 24+tmp.length] = tmp;
		
		return output[0 .. 26].dup;
	}
	
	void generate_sid() {
		sid = get_rand_sid();
	}
	
	void put_sid(string s) {
		sid = s;
		/*
		sid1 = cast(uint)dec_int(sid[0 .. 6]);
		sid2 = cast(uint)dec_int(sid[6 .. 12]);
		sid3 = cast(uint)dec_int(sid[12 .. 18]);
		sid4 = cast(uint)dec_int(sid[18 .. 24]);
		sid5 = cast(uint)dec_int(sid[24 .. 26]);
		*/
	}
	
	static Session get_session(string sid) {
		//uint sid1 = cast(uint)dec_int(sid[0 .. 6]);
		//uint[] sessions = SID1Sessions.list(sid1);
		Session s = new Session(`sid:"`~sid~'"');
		//foreach(ss; sessions) {
		do {
			if(s.sid == sid) {
				return s;
			}
		} while(s.loop());
		
		return null;
	}
	
	static int func_set_timezone() {
		string* ptr_tz = "tz" in FUNC;
		if(ptr_tz) {
			int tz = toInt(*ptr_tz);
			cur_session.timezone = -(tz*3600);
			return SUCCESS;
		}
		
		return FAILURE;
	}
}


class UserSession : EdbObject {
	mixin(GenDataModel!("UserSession", "
		int last_request;
		int hits;
		int page_hits;
	"));
}

