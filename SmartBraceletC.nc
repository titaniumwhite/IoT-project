#include "SmartBracelet.h"
#include "Timer.h"
#include "printf.h"
	
	module SmartBraceletC @safe() {
	
	  uses {
		interface Boot; 
	
		interface AMSend;
		interface Receive;
	    interface AMPacket; 
		interface Packet;
		interface PacketAcknowledgements;
	    interface SplitControl;
		interface Random;
	
	    interface Timer<TMilli> as TPairing;
		interface Timer<TMilli> as T10;
	    interface Timer<TMilli> as T60;
	
		
	  }
	
	} implementation {
		message_t packet;
		am_addr_t coupled_device;
		
		uint8_t attempt = 0;
		uint8_t phase = 0;
		
		bool is_radio_busy = FALSE;
		
		uint16_t last_position_x;
		uint16_t last_position_y;
		
		void send_confirmation();
		void send_info_message();
		void update_last_position(sb_msg_t* msg);
	  
	
		event void Boot.booted() {
			printf("Application correctly booted.\n");
			call SplitControl.start();
		}
	
		event void SplitControl.startDone(error_t err){
			if (err == SUCCESS) {
				
				if (TOS_NODE_ID % 2 == 0)
					printf("Parent: pairing phase started\n");
				else
					printf("Child: pairing phase started\n");
				
			// Start pairing phase, send two pairing message per second
				call TPairing.startPeriodic(500);
			} else {
				call SplitControl.start();
			}
	  	}
	  
		event void SplitControl.stopDone(error_t err){}
	
		event void TPairing.fired() {
			if (!is_radio_busy) {
				sb_msg_t* sb_msg = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
	      
	      		sb_msg->msg_type = PAIRING;
				strcpy(sb_msg->bracelet_key, RANDOM_KEY[(TOS_NODE_ID-1)/2]);
	
				if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(sb_msg_t)) == SUCCESS) {
					printf("Radio: pairing packet sent to bracelet %s\n", sb_msg->bracelet_key);	
					is_radio_busy = TRUE;
				}
	
			}
		}
	  
	
	  //********************* AMSend interface ****************//
		event void AMSend.sendDone(message_t* buf,error_t err) {
			if (&packet == buf && err == SUCCESS) {
				is_radio_busy = FALSE;
				
				// if we receive an ACK...
				if (call PacketAcknowledgements.wasAcked(buf)) {
					if (phase == 1) {
						phase = 2; 
						printf("Radio: pairing ack received\n");

						if (TOS_NODE_ID % 2 == 0){
						  // Parent bracelet, timer to check if we don't receive anymore any info message
						  call T60.startOneShot(60000);
						} else {
						  // Child bracelet, timer to send info messages-
						  call T10.startPeriodic(10000);
						}
					} else if (phase == 2) {
						printf("Radio: info ack received\n");
						attempt = 0;
					}

				} else if (phase == 1) {
					printf("Radio: pairing ack not received, send pairing confirmation message again\n");
					send_confirmation();

				} else if (phase == 2) {
					if (attempt == 3) {
						printf("Radio: info ack not received, 3 attempts already tried\n");
					} else {
						printf("Radio: info ack not received, send info message again\n");
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
				printf("Radio: message for pairing initialization received (phase 0). Address: %d\n", coupled_device);
				send_confirmation();
			
			} else if (call AMPacket.destination(buf) == TOS_NODE_ID) {
			 	if(msg->msg_type == PAIRING_COMPLETED) {
					printf("Radio: message for pairing confirmation received (phase 1)\n");
					call TPairing.stop();
				
				} else if(call AMPacket.source(buf) == coupled_device) {
					printf("Radio: message received\n");
				
					update_last_position(msg);
				
					if (msg->status == STANDING) {
						printf("Child is STANDING [%d]\n", msg->status);
						printf("x: %d, y: %d\n", msg->coord_x, msg->coord_y);
					} else if (msg->status == WALKING) {
						printf("Child is WALKING [%d]\n", msg->status);
						printf("x: %d, y: %d\n", msg->coord_x, msg->coord_y);
					} else if (msg->status == RUNNING) {
						printf("Child is RUNNING [%d]\n", msg->status);
						printf("x: %d, y: %d\n", msg->coord_x, msg->coord_y);
					} else if (msg->status == FALLING){
						printf("ALERT: CHILD FALLING [%d]\n", msg->status);
						printf("x: %d, y: %d\n", msg->coord_x, msg->coord_y);
					}
					
				}
			}
	
			return buf;
	  	}
		
			
		event void T10.fired() {
			printf("Timer10: fired\n");
			send_info_message();
		}
	
		event void T60.fired() {
			printf("Timer60: fired\n");
			printf("ALERT: CHILD MISSING\n");
			printf("Last known position x: %d, y: %d\n", last_position_x, last_position_y);
		}
		
		
		void update_last_position(sb_msg_t* msg){
				last_position_x = msg->coord_x;
				last_position_y = msg->coord_y;
				call T60.startOneShot(60000);
		}
		
		void send_confirmation(){
			if (!is_radio_busy) {
				sb_msg_t* sb_msg = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
				
				sb_msg->msg_type = PAIRING_COMPLETED; 
				strcpy(sb_msg->bracelet_key, RANDOM_KEY[(TOS_NODE_ID-1)/2]);
				
				call PacketAcknowledgements.requestAck(&packet);
			
				if (call AMSend.send(coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
					printf("Radio: sending pairing confirmation to node %d\n", coupled_device);	
					is_radio_busy = TRUE;
				}
			}
	  	}
	
		// Send INFO message from child's bracelet
		void send_info_message(){
			
			if (attempt == 3)
				attempt = 0;

			if (attempt < 3){
				uint8_t current_status;

				if (!is_radio_busy) {
					sb_msg_t* sb_msg = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));

					sb_msg->coord_x = call Random.rand16();
					sb_msg->coord_y = call Random.rand16();
					
					current_status = call Random.rand16() % 10;
					if (current_status >= 0 && current_status <= 2) {
						sb_msg->msg_type = INFO;
						sb_msg->status = STANDING;
					} else if (current_status >= 3 && current_status <= 5) {
						sb_msg->msg_type = INFO;
						sb_msg->status = WALKING;
					} else if (current_status >= 6 && current_status <= 8) {
						sb_msg->msg_type = INFO;
						sb_msg->status = RUNNING;
					} else if (current_status == 9) {
						sb_msg->msg_type = ALERT;
						sb_msg->status = FALLING;
					}
					
					attempt++;
					call PacketAcknowledgements.requestAck(&packet);
					
					if (call AMSend.send(coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
						printf("Radio: message sent to bracelet %d, attempt number %d\n", coupled_device, attempt);	
						is_radio_busy = TRUE;
					}
				}
			} else {
				attempt = 0;
			}
		} 
	

	}
