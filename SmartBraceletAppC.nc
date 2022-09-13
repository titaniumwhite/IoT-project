#include "SmartBracelet.h"
	
	configuration SmartBraceletAppC {}
	
	implementation {
	
	  components MainC, SmartBraceletC as App;
	  components new AMSenderC(AM_MSG);
	  components new AMReceiverC(AM_MSG);
	  components ActiveMessageC;
	  
	  components new TimerMilliC() as TimerPairing;
	  components new TimerMilliC() as Timer10;
	  components new TimerMilliC() as Timer60;
	
	  components SerialPrintfC;
	  components RandomC;
	
	  App.Boot -> MainC.Boot;
	
	  App.Receive -> AMReceiverC;
	  App.AMSend -> AMSenderC;
	  App.SplitControl -> ActiveMessageC;
	
	  App.AMPacket -> AMSenderC;
	  App.Packet -> AMSenderC;
	  App.PacketAcknowledgements -> ActiveMessageC;
	  
	  App.Random -> RandomC;
	  RandomC <- MainC.SoftwareInit;
	  
	  App.TPairing -> TimerPairing;
	  App.T10 -> Timer10;
	  App.T60 -> Timer60;

	}
