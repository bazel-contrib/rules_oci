package com.example;

import java.util.Arrays;

/** A simple client that sends messages to the server to be stored. */
public class JavaLoggingClient {

  public static void main(String[] args) throws Exception {
    JavaLoggingClientLibrary client = new JavaLoggingClientLibrary("localhost", 50051);
    System.out.println("Sending message to server");
    client.sendLogMessageToServer(Arrays.toString(args));
    client.shutdown();
  }
}
