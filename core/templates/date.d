module templates.date;
import core;
import panel;
import lib;
import shared;

enum {
	FORMAT_DATE = 1,
	FORMAT_DATE_USA,
	FORMAT_DELTA,
	FORMAT_DATETIME,
	FORMAT_DATETIME_USA,
	FORMAT_MONTHDATE,
	FORMAT_DATEDELTA,
	FORMAT_DATEDELTA_USA,
	FORMAT_YEAR,
	FORMAT_MONTH,
	FORMAT_MONTH_TXT,
	FORMAT_DAY,
	FORMAT_WEEKDAY,
}

class TemplateDate {
	import tango.stdc.time;
	import Integer = tango.text.convert.Integer;
	
	private static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("date", &this.create);
	}
	
	private static void create(PNL* pnl, string cmd, string inside) {
		instances ~= new typeof(this)(inside, pnl);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}
	
	private uint format = FORMAT_DATE;
	private bool show_online;
	private bool adjust_tz;
	
	private int* ptr_date;
	private int date;
	
	this(string params, PNL* pnl) {
		string[string] opts;
		string s_date;
		string* val;
		
		parse_options(params, opts);
		
		val = "date" in opts;
		if(val) {
			s_date = *val;
			
			if(s_date[1] >= '0' && s_date[1] <= '9') {
				date = toInt(s_date);
			} else if(s_date[0] == '$') {
				string var = s_date[1 .. $];
				int v_scope = pnl.find_var(var);
				if(v_scope >= 0) {
					if(pnl.var_type[v_scope][var] == pnl_action_var_int) {
						ptr_date = cast(int*)pnl.var_ptr[v_scope][var];
					}
				} else {
					debug errorln("variable '", var, "' is not registered");
				}
			}
			
		} else {
			debug errorln("You must supply the template 'date' with a 'date' field");
		}
		
		val = "show_online" in opts;
		if(val) {
			show_online = true;
		}
		
		
		val = "format" in opts;
		if(val) {
			adjust_tz = true;
			if(*val == "date") {
				format = FORMAT_DATE;
			} else if(*val == "date_usa") {
				format = FORMAT_DATE_USA;
			} else if(*val == "delta") {
				format = FORMAT_DELTA;
			} else if(*val == "datetime_usa") {
				format = FORMAT_DATETIME_USA;
			} else if(*val == "datetime") {
				format = FORMAT_DATETIME;
			} else if(*val == "monthdate") {
				format = FORMAT_MONTHDATE;
				adjust_tz = false;
			} else if(*val == "datedelta") {
				format = FORMAT_DATEDELTA;
			} else if(*val == "datedelta_usa") {
				format = FORMAT_DATEDELTA;
			} else if(*val == "year") {
				format = FORMAT_YEAR;
			} else if(*val == "month") {
				format = FORMAT_MONTH;
			} else if(*val == "month_txt") {
				format = FORMAT_MONTH_TXT;
			} else if(*val == "day") {
				format = FORMAT_DAY;
			} else if(*val == "weekday") {
				format = FORMAT_WEEKDAY;
			}
			
		}
	}
	
	void render() {
		char[40] tmp;
		if(ptr_date) {
			date = *ptr_date;
		}
		
		time_t date2 = date;
		/*
		//removed, because I don't really want to use session.timezone, cause sometimes it's not set
		if(adjust_tz) {
			date2 += session.timezone;
		}
		*/
		
		tm* tm_struct = gmtime(&date2);
		
		switch(format) {
		case FORMAT_DATE:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%d/%m/%Y\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
			
		case FORMAT_DATE_USA:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%m/%d/%Y\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
		case FORMAT_DELTA:
		case FORMAT_DATEDELTA:
		case FORMAT_DATEDELTA_USA:
			auto delta = request_time/* + session.timezone*/ - date;
			if(delta < 10) {
				if(show_online) {
					prt("online");
				} else {
					prt("seconds ago");
				}
			} else {
				if(delta < 60) {
					prt(Integer.toString(delta));
					prt(" seconds");
					if(delta == 1) {
						out_ptr--;
					}
				} else if(delta < 60*60) {
					auto minutes = delta / 60;
					prt(Integer.toString(minutes));
					prt(" minutes");
					if(minutes == 1) {
						out_ptr--;
					}
				} else if(delta < 24*60*60) {
					auto hours = delta / (60*60);
					prt(Integer.toString(hours));
					prt(" hours");
					if(hours == 1) {
						out_ptr--;
					}
				} else {
					if(format == FORMAT_DATEDELTA) {
						auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%d/%m/%Y\0", tm_struct);
						prt(tmp[0 .. str_len]);
					} else if(format == FORMAT_DATEDELTA_USA) {
						auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%m/%d/%Y\0", tm_struct);
						prt(tmp[0 .. str_len]);
					} else {
						auto days = delta / (24*60*60);
						prt(Integer.toString(days));
						prt(" days");
						if(days == 1) {
							out_ptr--;
						}
					}
				}
				
				if(format == FORMAT_DELTA || delta < 24*60*60) {
					prt(" ago");
				}
			}
			
			break;
		
		case FORMAT_DATETIME_USA:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%m/%d/%Y %H:%M\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
			
		case FORMAT_DATETIME:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%d/%m/%Y %H:%M\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
			
		case FORMAT_MONTHDATE:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%B %d\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
			
		case FORMAT_YEAR:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%Y\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
			
		case FORMAT_MONTH:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%m\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
			
		case FORMAT_MONTH_TXT:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%b\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
			
		case FORMAT_DAY:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%d\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
			
		case FORMAT_WEEKDAY:
			auto str_len = strftime(cast(char*)&tmp, 40, cast(char*)"%a\0", tm_struct);
			prt(tmp[0 .. str_len]);
			break;
		
		default:
		}
	}
}

