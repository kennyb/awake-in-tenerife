module templates.date;
import core;
import panel;
import lib;
import shared;

enum {
	FORMAT_DATE = 1,
	FORMAT_DATE_USA,
	FORMAT_DELTA,
	FORMAT_DELTA_HOURS,
	FORMAT_DELTA_MINUTES,
	FORMAT_DELTA_SECONDS,
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
	
	static private typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("date", &create);
	}
	
	static private void create(inout PNL pnl, string cmd, string inside) {
		instances ~= new typeof(this)(pnl, inside);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}
	
	private uint format = FORMAT_DATETIME;
	private bool show_online;
	private bool adjust_tz;
	
	private int* ptr_date;
	private int date;
	
	this(inout PNL pnl, string params) {
		string[string] opts;
		string s_date;
		string* val;
		
		opts.parse_options(params);
		
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
			switch(*val) {
			case "date":
				format = FORMAT_DATE; break;
			case "date_usa":
				format = FORMAT_DATE_USA; break;
			case "delta":
				format = FORMAT_DELTA; break;
			case "delta_hours":
				format = FORMAT_DELTA_HOURS; break;
			case "delta_minutes":
				format = FORMAT_DELTA_MINUTES; break;
			case "delta_seconds":
				format = FORMAT_DELTA_SECONDS; break;
			case "datetime_usa":
				format = FORMAT_DATETIME_USA; break;
			case "datetime":
				format = FORMAT_DATETIME; break;
			case "monthdate":
				format = FORMAT_MONTHDATE; break;
				adjust_tz = false;
			case "datedelta":
				format = FORMAT_DATEDELTA; break;
			case "datedelta_usa":
				format = FORMAT_DATEDELTA; break;
			case "year":
				format = FORMAT_YEAR; break;
			case "month":
				format = FORMAT_MONTH; break;
			case "month_txt":
				format = FORMAT_MONTH_TXT; break;
			case "day":
				format = FORMAT_DAY; break;
			case "weekday":
				format = FORMAT_WEEKDAY; break;
			default:
				errorln("unrecognized format: ", *val);
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
		case FORMAT_DELTA_HOURS:
		case FORMAT_DELTA_MINUTES:
		case FORMAT_DELTA_SECONDS:
		case FORMAT_DATEDELTA:
		case FORMAT_DATEDELTA_USA:
			int delta = request_time/* + session.timezone*/ - date;
			bool is_future = false;
			if(delta < 0) {
				is_future = true;
				delta = -delta;
			}
			
			if(delta < 10) {
				if(show_online) {
					prt("online");
				} else {
					prt("seconds ago");
				}
			} else {
				if(delta >= 24*60*60) {
					if(format == FORMAT_DATEDELTA) {
						auto str_len = strftime(cast(char*)&tmp, 40, "%d/%m/%Y\0", tm_struct);
						prt(tmp[0 .. str_len]);
						break;
					} else if(format == FORMAT_DATEDELTA_USA) {
						auto str_len = strftime(cast(char*)&tmp, 40, "%m/%d/%Y\0", tm_struct);
						prt(tmp[0 .. str_len]);
						break;
					} else {
						int days = delta / 24 / 60 / 60;
						delta -= days * 24 * 60 * 60;
						
						prt(Integer.toString(days));
						prt(" days");
						if(days == 1) {
							out_ptr--;
						}
						
						if(format == FORMAT_DELTA ) {
							goto delta_ending;
						} else {
							prt(" ");
						}
					}
				}
				
				if(delta >= 60 * 60) {
					int hours = delta / 60 / 60;
					delta -= hours * 60 * 60;
					
					prt(Integer.toString(hours));
					prt(" hours");
					if(hours == 1) {
						out_ptr--;
					}
					
					if(format == FORMAT_DELTA || format == FORMAT_DELTA_HOURS) {
						goto delta_ending;
					} else {
						prt(" ");
					}
				}
				
				if(delta >= 60) {
					int minutes = delta / 60;
					delta -= minutes * 60;
					
					prt(Integer.toString(minutes));
					prt(" minutes");
					if(minutes == 1) {
						out_ptr--;
					}
					
					if(format == FORMAT_DELTA || format == FORMAT_DELTA_HOURS || format == FORMAT_DELTA_MINUTES) {
						goto delta_ending;
					} else {
						prt(" ");
					}
				}
				
				if(delta < 60) {
					prt(Integer.toString(delta));
					prt(" seconds");
					if(delta == 1) {
						out_ptr--;
					}
				}
				
delta_ending:
				if(format == FORMAT_DELTA || delta < 24*60*60) {
					if(is_future) {
						prt(" from now");
					} else {
						prt(" ago");
					}
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

