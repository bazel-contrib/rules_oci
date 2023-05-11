package com.example;

import static io.grpc.MethodDescriptor.generateFullMethodName;

/**
 */
@io.grpc.stub.annotations.GrpcGenerated
public final class LoggerGrpc {

  private LoggerGrpc() {}

  public static final String SERVICE_NAME = "Logger";

  // Static method descriptors that strictly reflect the proto.
  private static volatile io.grpc.MethodDescriptor<com.example.LogMessage,
      com.example.Empty> getSendLogMessageMethod;

  @io.grpc.stub.annotations.RpcMethod(
      fullMethodName = SERVICE_NAME + '/' + "SendLogMessage",
      requestType = com.example.LogMessage.class,
      responseType = com.example.Empty.class,
      methodType = io.grpc.MethodDescriptor.MethodType.UNARY)
  public static io.grpc.MethodDescriptor<com.example.LogMessage,
      com.example.Empty> getSendLogMessageMethod() {
    io.grpc.MethodDescriptor<com.example.LogMessage, com.example.Empty> getSendLogMessageMethod;
    if ((getSendLogMessageMethod = LoggerGrpc.getSendLogMessageMethod) == null) {
      synchronized (LoggerGrpc.class) {
        if ((getSendLogMessageMethod = LoggerGrpc.getSendLogMessageMethod) == null) {
          LoggerGrpc.getSendLogMessageMethod = getSendLogMessageMethod =
              io.grpc.MethodDescriptor.<com.example.LogMessage, com.example.Empty>newBuilder()
              .setType(io.grpc.MethodDescriptor.MethodType.UNARY)
              .setFullMethodName(generateFullMethodName(SERVICE_NAME, "SendLogMessage"))
              .setSampledToLocalTracing(true)
              .setRequestMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  com.example.LogMessage.getDefaultInstance()))
              .setResponseMarshaller(io.grpc.protobuf.ProtoUtils.marshaller(
                  com.example.Empty.getDefaultInstance()))
              .setSchemaDescriptor(new LoggerMethodDescriptorSupplier("SendLogMessage"))
              .build();
        }
      }
    }
    return getSendLogMessageMethod;
  }

  /**
   * Creates a new async stub that supports all call types for the service
   */
  public static LoggerStub newStub(io.grpc.Channel channel) {
    io.grpc.stub.AbstractStub.StubFactory<LoggerStub> factory =
      new io.grpc.stub.AbstractStub.StubFactory<LoggerStub>() {
        @java.lang.Override
        public LoggerStub newStub(io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
          return new LoggerStub(channel, callOptions);
        }
      };
    return LoggerStub.newStub(factory, channel);
  }

  /**
   * Creates a new blocking-style stub that supports unary and streaming output calls on the service
   */
  public static LoggerBlockingStub newBlockingStub(
      io.grpc.Channel channel) {
    io.grpc.stub.AbstractStub.StubFactory<LoggerBlockingStub> factory =
      new io.grpc.stub.AbstractStub.StubFactory<LoggerBlockingStub>() {
        @java.lang.Override
        public LoggerBlockingStub newStub(io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
          return new LoggerBlockingStub(channel, callOptions);
        }
      };
    return LoggerBlockingStub.newStub(factory, channel);
  }

  /**
   * Creates a new ListenableFuture-style stub that supports unary calls on the service
   */
  public static LoggerFutureStub newFutureStub(
      io.grpc.Channel channel) {
    io.grpc.stub.AbstractStub.StubFactory<LoggerFutureStub> factory =
      new io.grpc.stub.AbstractStub.StubFactory<LoggerFutureStub>() {
        @java.lang.Override
        public LoggerFutureStub newStub(io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
          return new LoggerFutureStub(channel, callOptions);
        }
      };
    return LoggerFutureStub.newStub(factory, channel);
  }

  /**
   */
  public static abstract class LoggerImplBase implements io.grpc.BindableService {

    /**
     */
    public void sendLogMessage(com.example.LogMessage request,
        io.grpc.stub.StreamObserver<com.example.Empty> responseObserver) {
      io.grpc.stub.ServerCalls.asyncUnimplementedUnaryCall(getSendLogMessageMethod(), responseObserver);
    }

    @java.lang.Override public final io.grpc.ServerServiceDefinition bindService() {
      return io.grpc.ServerServiceDefinition.builder(getServiceDescriptor())
          .addMethod(
            getSendLogMessageMethod(),
            io.grpc.stub.ServerCalls.asyncUnaryCall(
              new MethodHandlers<
                com.example.LogMessage,
                com.example.Empty>(
                  this, METHODID_SEND_LOG_MESSAGE)))
          .build();
    }
  }

  /**
   */
  public static final class LoggerStub extends io.grpc.stub.AbstractAsyncStub<LoggerStub> {
    private LoggerStub(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      super(channel, callOptions);
    }

    @java.lang.Override
    protected LoggerStub build(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      return new LoggerStub(channel, callOptions);
    }

    /**
     */
    public void sendLogMessage(com.example.LogMessage request,
        io.grpc.stub.StreamObserver<com.example.Empty> responseObserver) {
      io.grpc.stub.ClientCalls.asyncUnaryCall(
          getChannel().newCall(getSendLogMessageMethod(), getCallOptions()), request, responseObserver);
    }
  }

  /**
   */
  public static final class LoggerBlockingStub extends io.grpc.stub.AbstractBlockingStub<LoggerBlockingStub> {
    private LoggerBlockingStub(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      super(channel, callOptions);
    }

    @java.lang.Override
    protected LoggerBlockingStub build(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      return new LoggerBlockingStub(channel, callOptions);
    }

    /**
     */
    public com.example.Empty sendLogMessage(com.example.LogMessage request) {
      return io.grpc.stub.ClientCalls.blockingUnaryCall(
          getChannel(), getSendLogMessageMethod(), getCallOptions(), request);
    }
  }

  /**
   */
  public static final class LoggerFutureStub extends io.grpc.stub.AbstractFutureStub<LoggerFutureStub> {
    private LoggerFutureStub(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      super(channel, callOptions);
    }

    @java.lang.Override
    protected LoggerFutureStub build(
        io.grpc.Channel channel, io.grpc.CallOptions callOptions) {
      return new LoggerFutureStub(channel, callOptions);
    }

    /**
     */
    public com.google.common.util.concurrent.ListenableFuture<com.example.Empty> sendLogMessage(
        com.example.LogMessage request) {
      return io.grpc.stub.ClientCalls.futureUnaryCall(
          getChannel().newCall(getSendLogMessageMethod(), getCallOptions()), request);
    }
  }

  private static final int METHODID_SEND_LOG_MESSAGE = 0;

  private static final class MethodHandlers<Req, Resp> implements
      io.grpc.stub.ServerCalls.UnaryMethod<Req, Resp>,
      io.grpc.stub.ServerCalls.ServerStreamingMethod<Req, Resp>,
      io.grpc.stub.ServerCalls.ClientStreamingMethod<Req, Resp>,
      io.grpc.stub.ServerCalls.BidiStreamingMethod<Req, Resp> {
    private final LoggerImplBase serviceImpl;
    private final int methodId;

    MethodHandlers(LoggerImplBase serviceImpl, int methodId) {
      this.serviceImpl = serviceImpl;
      this.methodId = methodId;
    }

    @java.lang.Override
    @java.lang.SuppressWarnings("unchecked")
    public void invoke(Req request, io.grpc.stub.StreamObserver<Resp> responseObserver) {
      switch (methodId) {
        case METHODID_SEND_LOG_MESSAGE:
          serviceImpl.sendLogMessage((com.example.LogMessage) request,
              (io.grpc.stub.StreamObserver<com.example.Empty>) responseObserver);
          break;
        default:
          throw new AssertionError();
      }
    }

    @java.lang.Override
    @java.lang.SuppressWarnings("unchecked")
    public io.grpc.stub.StreamObserver<Req> invoke(
        io.grpc.stub.StreamObserver<Resp> responseObserver) {
      switch (methodId) {
        default:
          throw new AssertionError();
      }
    }
  }

  private static abstract class LoggerBaseDescriptorSupplier
      implements io.grpc.protobuf.ProtoFileDescriptorSupplier, io.grpc.protobuf.ProtoServiceDescriptorSupplier {
    LoggerBaseDescriptorSupplier() {}

    @java.lang.Override
    public com.google.protobuf.Descriptors.FileDescriptor getFileDescriptor() {
      return com.example.GreeterProto.getDescriptor();
    }

    @java.lang.Override
    public com.google.protobuf.Descriptors.ServiceDescriptor getServiceDescriptor() {
      return getFileDescriptor().findServiceByName("Logger");
    }
  }

  private static final class LoggerFileDescriptorSupplier
      extends LoggerBaseDescriptorSupplier {
    LoggerFileDescriptorSupplier() {}
  }

  private static final class LoggerMethodDescriptorSupplier
      extends LoggerBaseDescriptorSupplier
      implements io.grpc.protobuf.ProtoMethodDescriptorSupplier {
    private final String methodName;

    LoggerMethodDescriptorSupplier(String methodName) {
      this.methodName = methodName;
    }

    @java.lang.Override
    public com.google.protobuf.Descriptors.MethodDescriptor getMethodDescriptor() {
      return getServiceDescriptor().findMethodByName(methodName);
    }
  }

  private static volatile io.grpc.ServiceDescriptor serviceDescriptor;

  public static io.grpc.ServiceDescriptor getServiceDescriptor() {
    io.grpc.ServiceDescriptor result = serviceDescriptor;
    if (result == null) {
      synchronized (LoggerGrpc.class) {
        result = serviceDescriptor;
        if (result == null) {
          serviceDescriptor = result = io.grpc.ServiceDescriptor.newBuilder(SERVICE_NAME)
              .setSchemaDescriptor(new LoggerFileDescriptorSupplier())
              .addMethod(getSendLogMessageMethod())
              .build();
        }
      }
    }
    return result;
  }
}
