# Project for the Internet of Things course #
### @Politecnico di Milano, Academic Year 2021-2022 ###
The aim of this project is to design, implement and test a software prototype for a set of smart bracelets.  
These bracelets are used by parents to keep track of their children’s position and to alert them when a child goes too far. Parent and child bracelets are coupled together in order to exchange these alerts. 

The project has been developed through TinyOS and tested over Cooja. Node-red has been used to collect the Alarm messages.
  
The operations of the smart bracelet couple are as follows:  
* <b>Pairing phase</b>: the parent’s bracelet and the child’s bracelet broadcast a 20-char random key used to uniquely couple the two devices. The same random key is pre-loaded at production time on the two devices: upon reception of a random key, a device checks whether the received random key is equal to the stored one; if yes, it stores the address of the source device in memory. Then, a special message is transmitted (in unicast) to the source device to stop the pairing phase and move to the next step.  
* <b>Operation mode</b>: the parent’s bracelet listen for messages on the radio and accepts only messages coming from the child’s bracelet. The child’s bracelet periodically
transmits INFO messages (one message every 10 seconds), containing the position (X,Y) of the child and an estimate of his/her kinematic status (STANDING, WALKING, RUNNING, FALLING).  
* <b>Alert Mode</b>: upon reception of an INFO message, the parent’s bracelet reads the content of the message. If the kinematic status is FALLING, the bracelet sends a FALL alarm, reporting the position (X, Y) of the children. If the parent’s bracelet does not receive any message, after one minute from the last received message, a MISSING alarm is sent reporting the last position received.  
