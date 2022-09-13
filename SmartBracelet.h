#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H
	
	//payload of the msg
	typedef nx_struct sb_msg{
		nx_uint8_t msg_type;
		nx_uint8_t msg_id;
	
		nx_uint8_t bracelet_key[20];
		nx_uint8_t status;
		nx_uint16_t coord_x;
		nx_uint16_t coord_y;
	}sb_msg_t;
	
	#define PAIRING 1
	#define PAIRING_COMPLETED 2
	#define INFO 3
	#define ALERT 4
	
	#define STANDING 0
	#define WALKING 1
	#define RUNNING 2
	#define FALLING 3
	
	#define FOREACH_KEY(KEY) \
		KEY(KGXQBDgRlJLF92jbKw58) \
		KEY(Xq7sVPILQUpdMuEGM1nN) \
		KEY(BNF97WV7VSMNL6NTWsdy) \
		KEY(UyY3JKnlUcwf0KkyWELr) \
		KEY(vyr1Wz15zllPpBuOyD6x) \
		KEY(NPDLGIK0EJOlh6LAdyZG) \
		KEY(Y1XLnhuNyXSSJXYZR7H7) \
		KEY(hDuYRJlD1fSrru4dSzZ0) \
		KEY(qdcUIJb57biPriyvFNyG) \
	
	#define GENERATE_ENUM(ENUM) ENUM,
	#define GENERATE_STRING(STRING) #STRING,
	
	enum KEY_ENUM {
	    FOREACH_KEY(GENERATE_ENUM)
	};
	
	enum{
		AM_MSG = 6,
	};
	
	static const char *RANDOM_KEY[] = {
	    FOREACH_KEY(GENERATE_STRING)
	};
		
	
	
#endif
