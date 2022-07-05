#include "smartBracelets.h"
#include "Timer.h"

module smartBraceletsC @safe() {

  uses {
	interface Boot; 

	interface AMSend;
	interface Receive;
    interface AMPacket; 
	interface Packet;
	interface PacketAcknowledgements;
    interface SplitControl as AMControl;
	interface Random;

    interface Timer<TMilli> as TimerPairing;
	interface Timer<TMilli> as Timer10s;
    interface Timer<TMilli> as Timer60s;

	
  }

} implementation {

	// Radio control
	bool busy = FALSE;
	message_t packet;
	am_addr_t coupled_device;
	uint8_t attempt = 0;
	
	uint8_t phase = 0;

	uint16_t last_x;
	uint16_t last_y;
	
	void send_confirmation();
	void send_info_message();
  

	event void Boot.booted() {
		dbg("boot","Application booted.\n");
		call AMControl.start();
	}

	event void SplitControl.startDone(error_t err){
		if (err == SUCCESS) {
			if (TOS_NODE_ID % 2 == 0){
				printf("[PARENT] Pairing phase started\n");
			} else {
				printf("[CHILD] Pairing phase started\n");
			}
		// Start pairing phase
			call TimerPairing.startPeriodic(250);
		} else {
			call AMControl.start();
		}
  	}
  
	event void SplitControl.stopDone(error_t err){}

	event void TimerPairing.fired() {
		if (!busy) {
			sb_msg_t* sb_msg = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
      
      		sb_msg->msg_type = KEY;
			strcpy(sb_msg->bracelet_key, RANDOM_KEY[(TOS_NODE_ID-1)/2]);

			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(sb_msg_t)) == SUCCESS) {
				printf("[RADIO] Pairing packet sent with key=%s\n", RANDOM_KEY[(TOS_NODE_ID-1)/2]);	
				busy = TRUE;
			}

		}
	}
  

  //********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf,error_t err) {
		if (&packet == buf && error == SUCCESS) {
			busy = FALSE;

			if (phase == 1){
				if (call PacketAcknowledgements.wasAcked(bufPtr)) {
					phase = INFO; 
							
					// Start operational phase
					if (TOS_NODE_ID % 2 == 0){
						// Parent bracelet
						printf("[PARENT] Pairing ack received\n");
						call Timer60s.startOneShot(60000);
					} else {
						// Child bracelet
						printf("[CHILD] Pairing ack received\n");
						call Timer10s.startPeriodic(10000);
					}
				} else {
					if (TOS_NODE_ID % 2 == 0){
						// Parent bracelet
						printf("[PARENT] Pairing ack not received\n");
					} else {
						// Child bracelet
						printf("[CHILD] Pairing ack not received\n");
					}

        			send_confirmation();
				}

			} else if (phase == 2) {
				if (call PacketAcknowledgements.wasAcked(bufPtr)) {
					if (TOS_NODE_ID % 2 == 0){
						// Parent bracelet
						printf("[PARENT] Info ack received\n");
					} else {
						// Child bracelet
						printf("[CHILD] Info ack received\n");
					}
					attempt = 0;
				} else {
					if (TOS_NODE_ID % 2 == 0){
						// Parent bracelet
						printf("[PARENT] Pairing ack not received\n");
					} else {
						// Child bracelet
						printf("[CHILD] Pairing ack not received\n");
					}

        			send_info_message();
				}
				
			}

		}
	}

  	event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {

		sb_msg_t* msg=(sb_msg_t*)payload;

		if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && phase == 0 && strcmp(msg->bracelet_key, RANDOM_KEY[(TOS_NODE_ID-1)/2]) == 0){

			coupled_device = call AMPacket.source(buf);
			phase = 1; 
			printf("Message for pairing phase 0 received. Address: %d\n", coupled_device);
			send_confirmation();
		
		} else if (call AMPacket.destination(buf) == TOS_NODE_ID && msg->msg_type == DONE) {
			printf("Message for pairing phase 1 received\n");
			call TimerPairing.stop();
		
		} else if (call AMPacket.destination(buf) == TOS_NODE_ID && call AMPacket.source(buf) == coupled_device && msg->msg_type == INFO) {
			printf("INFO message received\n");
			printf("Position X: %d, Y: %d\n", msg->coord_x, msg->coord_y);
			printf("Sensor status: %d\n", mess->status);
			last_x = msg->coord_x;
			last_y = msg->coord_y;
			call Timer60s.startOneShot(60000);
			
			// check if FALLING
			if (msg->status == FALLING){
				printf("ALERT: CHILD FALLING!\n");
				printf("Position (x,y) = (%d,%d)\n", msg->coord_x, msg->coord_y);
			}
		}

		return buf;
  	}
	
	void send_confirmation(){
		if (!busy) {
			sb_msg_t* sb_msg = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
			
			sb_msg->msg_type = DONE; 
			strcpy(sb_msg->bracelet_key, RANDOM_KEY[(TOS_NODE_ID-1)/2]);
			
			call PacketAcknowledgements.requestAck(&packet);
		
			if (call AMSend.send(coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
				printf("Radio: sending pairing confirmation to node %d\n", coupled_device);	
				busy = TRUE;
			}
		}
  	}

	// Send INFO message from child's bracelet
	void send_info_message(){
		
		if (attempt < 3){
			if (!busy) {
				sb_msg_t* rcm = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
				
				sb_msg->msg_type = INFO;
				sb_msg->coord_x = call Random.rand16();
				sb_msg->coord_y = call Random.rand16();
				
				current_status = call Random.rand16() % 10;
				if (current_status == 0 || current_status == 1 || current_status == 2)
					sb_msg->status = STANDING;
				else if (current_status == 3 || current_status == 4 || current_status == 5)
					sb_msg->status = WALKING;
				else if (current_status == 6 || current_status == 7 || current_status == 8)
					sb_msg->status = RUNNING;
				else // current_status == 9
					sb_msg->status = FALLING;
				
				attempt++;
				call PacketAcknowledgements.requestAck(&packet);
				
				if (call AMSend.send(coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
					printf("Radio: sanding INFO packet to node %d, attempt: %d\n", coupled_device, attempt);	
					busy = TRUE;
				}
			}
		} else {
			attempt = 0;
		}
	} 


	event void Timer10.fired() {
		printf("[Timer10] Fired\n");
		send_info_message();
	}

	event void Timer60.fired() {
		printf("[Timer60] Fired\n");
		printf("ALERT: CHILD MISSING\n");
		printf("Last known position (x,y) = (%d,%d)\n", last_x, last_y);
	}
}

