module externs;

extern(C) {
	void debug_verify_access(); // generic method that must be defined in the user
	
	version(datatest) {
		void make_tests();
	}
	
	version(generate) {
		//import generate.funcs;
		void start_activity();
	}
	
	version(unittests) {
		void reset_state();
		//void RUN_UNITTESTS();
		//void delegate()[string] UNITTESTS;
	}
	
	// these are native D functions
	int raise(int);
	void _STD_monitor_staticdtor();
	void _STD_critical_term();
	void gc_term();
	void _moduleDtor();
}
