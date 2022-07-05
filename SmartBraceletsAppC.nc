#include "smartBracelets.h"

configuration smartBraceletsAppC {}

implementation {

  components MainC, smartBraceletsC as App;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components ActiveMessageC as RadioAM;
  
  components new TimerMilliC() as TimerPairing;
  components new TimerMilliC() as Timer10;
  components new TimerMilliC() as Timer60;

  components SerialActiveMessageC as AMSerial;
  components SerialPrintfC;
  components SerialStartC;
  components RandomC;


  App.Boot -> MainC.Boot;

  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> RadioAM;

  App.AMPacket -> AMSenderC;
  App.Packet -> AMSenderC;
  App.PacketAcknowledgements -> RadioAM;

  App.TimerPairing -> TimerPairing;
  App.Timer10 -> Timer10;
  App.Timer60 -> Timer60;

}

