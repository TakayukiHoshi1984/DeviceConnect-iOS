#import "HTTPServer.h"
#import "GCDAsyncSocket.h"
#import "HTTPConnection.h"
#import "HTTPLogging.h"
#import "WebSocket.h"
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Does ARC support support GCD objects?
// It does if the minimum deployment target is iOS 6+ or Mac OS X 8+

#if TARGET_OS_IPHONE

  // Compiling for iOS

  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else                                         // iOS 5.X or earlier
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1
  #endif

#else

  // Compiling for Mac OS X

  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
  #endif

#endif
#define TIMEOUT_READ_FIRST_HEADER_LINE       30
#define TIMEOUT_READ_SUBSEQUENT_HEADER_LINE  30
#define MAX_HEADER_LINE_LENGTH             8190
#define HTTP_REQUEST_HEADER                  10
@interface HTTPServer (PrivateAPI)

- (void)unpublishBonjour;
- (void)publishBonjour;

+ (void)startBonjourThreadIfNeeded;
+ (void)performBonjourBlock:(dispatch_block_t)block;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation HTTPServer

/**
 * Standard Constructor.
 * Instantiates an HTTP server, but does not start it.
**/
- (id)init
{
	if ((self = [super init]))
	{

		// Initialize underlying dispatch queue and GCD based tcp socket
		serverQueue = dispatch_queue_create("HTTPServer", NULL);
		asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:serverQueue];

		// Use default connection class of HTTPConnection
		connectionQueue = dispatch_queue_create("HTTPConnection", NULL);
		connectionClass = [HTTPConnection self];
		
		// By default bind on all available interfaces, en1, wifi etc
		interface = nil;
		
		// Use a default port of 0
		// This will allow the kernel to automatically pick an open port for us
		port = 0;
		
		// Configure default values for bonjour service
		
		// Bonjour domain. Use the local domain by default
		domain = @"local.";
		
		// If using an empty string ("") for the service name when registering,
		// the system will automatically use the "Computer Name".
		// Passing in an empty string will also handle name conflicts
		// by automatically appending a digit to the end of the name.
		name = @"";
		
		// Initialize arrays to hold all the HTTP and webSocket connections
		connections = [[NSMutableArray alloc] init];
		webSockets  = [[NSMutableArray alloc] init];
		
		connectionsLock = [[NSLock alloc] init];
		webSocketsLock  = [[NSLock alloc] init];
		
		// Register for notifications of closed connections
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(connectionDidDie:)
		                                             name:HTTPConnectionDidDieNotification
		                                           object:nil];
		
		// Register for notifications of closed websocket connections
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(webSocketDidDie:)
		                                             name:WebSocketDidDieNotification
		                                           object:nil];
		
		isRunning = NO;
	}
	return self;
}
/**
 * Standard Deconstructor.
 * Stops the server, and clients, and releases any resources connected with this instance.
**/
- (void)dealloc
{
	
	// Remove notification observer
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Stop the server if it's running
	[self stop];
    for (HTTPConnection *con in connections) {
        [con stopWebSocket];
    }
	// Release all instance variables
	
	#if NEEDS_DISPATCH_RETAIN_RELEASE
	dispatch_release(serverQueue);
	dispatch_release(connectionQueue);
	#endif
	
	[asyncSocket setDelegate:nil delegateQueue:NULL];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The document root is filesystem root for the webserver.
 * Thus requests for /index.html will be referencing the index.html file within the document root directory.
 * All file requests are relative to this document root.
**/
- (NSString *)documentRoot
{
	__block NSString *result;
	
	dispatch_sync(serverQueue, ^{
		result = documentRoot;
	});
	
	return result;
}

- (void)setDocumentRoot:(NSString *)value
{
	// Document root used to be of type NSURL.
	// Add type checking for early warning to developers upgrading from older versions.
	
	if (value && ![value isKindOfClass:[NSString class]])
	{
		return;
	}
	
	NSString *valueCopy = [value copy];
	
	dispatch_async(serverQueue, ^{
		documentRoot = valueCopy;
	});
	
}

/**
 * The connection class is the class that will be used to handle connections.
 * That is, when a new connection is created, an instance of this class will be intialized.
 * The default connection class is HTTPConnection.
 * If you use a different connection class, it is assumed that the class extends HTTPConnection
**/
- (Class)connectionClass
{
	__block Class result;
	
	dispatch_sync(serverQueue, ^{
		result = connectionClass;
	});
	
	return result;
}

- (void)setConnectionClass:(Class)value
{
	dispatch_async(serverQueue, ^{
		connectionClass = value;
	});
}

/**
 * What interface to bind the listening socket to.
**/
- (NSString *)interface
{
	__block NSString *result;
	
	dispatch_sync(serverQueue, ^{
		result = interface;
	});
	
	return result;
}

- (void)setInterface:(NSString *)value
{
	NSString *valueCopy = [value copy];
	
	dispatch_async(serverQueue, ^{
		interface = valueCopy;
	});
	
}

/**
 * The port to listen for connections on.
 * By default this port is initially set to zero, which allows the kernel to pick an available port for us.
 * After the HTTP server has started, the port being used may be obtained by this method.
**/
- (UInt16)port
{
	__block UInt16 result;
	
	dispatch_sync(serverQueue, ^{
		result = port;
	});
	
    return result;
}

- (UInt16)listeningPort
{
	__block UInt16 result;
	
	dispatch_sync(serverQueue, ^{
		if (isRunning)
			result = [asyncSocket localPort];
		else
			result = 0;
	});
	
	return result;
}

- (void)setPort:(UInt16)value
{
	dispatch_async(serverQueue, ^{
		port = value;
	});
}

/**
 * Domain on which to broadcast this service via Bonjour.
 * The default domain is @"local".
**/
- (NSString *)domain
{
	__block NSString *result;
	
	dispatch_sync(serverQueue, ^{
		result = domain;
	});
	
    return result;
}

- (void)setDomain:(NSString *)value
{
	NSString *valueCopy = [value copy];
	
	dispatch_async(serverQueue, ^{
		domain = valueCopy;
	});
	
}

/**
 * The name to use for this service via Bonjour.
 * The default name is an empty string,
 * which should result in the published name being the host name of the computer.
**/
- (NSString *)name
{
	__block NSString *result;
	
	dispatch_sync(serverQueue, ^{
		result = name;
	});
	
	return result;
}

- (NSString *)publishedName
{
	__block NSString *result;
	
	dispatch_sync(serverQueue, ^{
		
		if (netService == nil)
		{
			result = nil;
		}
		else
		{
			
			dispatch_block_t bonjourBlock = ^{
				result = [[netService name] copy];
			};
			
			[[self class] performBonjourBlock:bonjourBlock];
		}
	});
	
	return result;
}

- (void)setName:(NSString *)value
{
	NSString *valueCopy = [value copy];
	
	dispatch_async(serverQueue, ^{
		name = valueCopy;
	});
	
}

/**
 * The type of service to publish via Bonjour.
 * No type is set by default, and one must be set in order for the service to be published.
**/
- (NSString *)type
{
	__block NSString *result;
	
	dispatch_sync(serverQueue, ^{
		result = type;
	});
	
	return result;
}

- (void)setType:(NSString *)value
{
	NSString *valueCopy = [value copy];
	
	dispatch_async(serverQueue, ^{
		type = valueCopy;
	});
	
}

/**
 * The extra data to use for this service via Bonjour.
**/
- (NSDictionary *)TXTRecordDictionary
{
	__block NSDictionary *result;
	
	dispatch_sync(serverQueue, ^{
		result = txtRecordDictionary;
	});
	
	return result;
}
- (void)setTXTRecordDictionary:(NSDictionary *)value
{
	NSDictionary *valueCopy = [value copy];
	
	dispatch_async(serverQueue, ^{
	
		txtRecordDictionary = valueCopy;
		
		// Update the txtRecord of the netService if it has already been published
		if (netService)
		{
			NSNetService *theNetService = netService;
			NSData *txtRecordData = nil;
			if (txtRecordDictionary)
				txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDictionary];
			
			dispatch_block_t bonjourBlock = ^{
				[theNetService setTXTRecordData:txtRecordData];
			};
			
			[[self class] performBonjourBlock:bonjourBlock];
		}
	});
	
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Control
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)start:(NSError **)errPtr
{
	__block BOOL success = YES;
	__block NSError *err = nil;
	
	dispatch_sync(serverQueue, ^{ @autoreleasepool {
		
		success = [asyncSocket acceptOnInterface:interface port:port error:&err];
		if (success)
		{
			isRunning = YES;
			[self publishBonjour];
		}
	}});
	
	if (errPtr)
		*errPtr = err;
	
	return success;
}

- (void)stop
{
	[self stop:NO];
}

- (void)stop:(BOOL)keepExistingConnections
{
	dispatch_sync(serverQueue, ^{ @autoreleasepool {
		
		// First stop publishing the service via bonjour
		[self unpublishBonjour];
		
		// Stop listening / accepting incoming connections
		[asyncSocket disconnect];
		isRunning = NO;
		
		if (!keepExistingConnections)
		{
			// Stop all HTTP connections the server owns
			[connectionsLock lock];
			for (HTTPConnection *connection in connections)
			{
				[connection stop];
			}
			[connections removeAllObjects];
			[connectionsLock unlock];
			
			// Stop all WebSocket connections the server owns
			[webSocketsLock lock];
			for (WebSocket *webSocket in webSockets)
			{
				[webSocket stop];
			}
			[webSockets removeAllObjects];
			[webSocketsLock unlock];
		}
	}});
}

- (BOOL)isRunning
{
	__block BOOL result;
	
	dispatch_sync(serverQueue, ^{
		result = isRunning;
	});
	
	return result;
}

- (void)addWebSocket:(WebSocket *)ws
{
	[webSocketsLock lock];
	
	[webSockets addObject:ws];
	
	[webSocketsLock unlock];
}

- (void)sendEvent:(NSString *)event forSessionKey:(NSString *)sessionKey
{
    for (HTTPConnection *connection in connections) {
        [connection sendEvent:event forSessionKey:sessionKey];
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Status
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the number of http client connections that are currently connected to the server.
**/
- (NSUInteger)numberOfHTTPConnections
{
	NSUInteger result = 0;
	
	[connectionsLock lock];
	result = [connections count];
	[connectionsLock unlock];
	
	return result;
}

/**
 * Returns the number of websocket client connections that are currently connected to the server.
**/
- (NSUInteger)numberOfWebSocketConnections
{
	NSUInteger result = 0;
	
	[webSocketsLock lock];
	result = [webSockets count];
	[webSocketsLock unlock];
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Incoming Connections
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (HTTPConfig *)config
{
	// Override me if you want to provide a custom config to the new connection.
	// 
	// Generally this involves overriding the HTTPConfig class to include any custom settings,
	// and then having this method return an instance of 'MyHTTPConfig'.
	
	// Note: Think you can make the server faster by putting each connection on its own queue?
	// Then benchmark it before and after and discover for yourself the shocking truth!
	// 
	// Try the apache benchmark tool (already installed on your Mac):
	// $  ab -n 1000 -c 1 http://localhost:<port>/some_path.html
	
	return [[HTTPConfig alloc] initWithServer:self documentRoot:documentRoot queue:connectionQueue];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
	HTTPConnection *newConnection = (HTTPConnection *)[[connectionClass alloc] initWithAsyncSocket:newSocket
	                                                                                 configuration:[self config]];
	[connectionsLock lock];
	[connections addObject:newConnection];
	[connectionsLock unlock];
	[newConnection start];
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)publishBonjour
{
	NSAssert(dispatch_get_current_queue() == serverQueue, @"Invalid queue");
	
	if (type)
	{
		netService = [[NSNetService alloc] initWithDomain:domain type:type name:name port:[asyncSocket localPort]];
		[netService setDelegate:self];
		
		NSNetService *theNetService = netService;
		NSData *txtRecordData = nil;
		if (txtRecordDictionary)
			txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDictionary];
		
		dispatch_block_t bonjourBlock = ^{
			
			[theNetService removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
			[theNetService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
			[theNetService publish];
			
			// Do not set the txtRecordDictionary prior to publishing!!!
			// This will cause the OS to crash!!!
			if (txtRecordData)
			{
				[theNetService setTXTRecordData:txtRecordData];
			}
		};
		
		[[self class] startBonjourThreadIfNeeded];
		[[self class] performBonjourBlock:bonjourBlock];
	}
}

- (void)unpublishBonjour
{
	NSAssert(dispatch_get_current_queue() == serverQueue, @"Invalid queue");
	
	if (netService)
	{
		NSNetService *theNetService = netService;
		
		dispatch_block_t bonjourBlock = ^{
			
			[theNetService stop];
		};
		
		[[self class] performBonjourBlock:bonjourBlock];
		
		netService = nil;
	}
}

/**
 * Republishes the service via bonjour if the server is running.
 * If the service was not previously published, this method will publish it (if the server is running).
**/
- (void)republishBonjour
{
	dispatch_async(serverQueue, ^{
		
		[self unpublishBonjour];
		[self publishBonjour];
	});
}

/**
 * Called when our bonjour service has been successfully published.
 * This method does nothing but output a log message telling us about the published service.
**/
- (void)netServiceDidPublish:(NSNetService *)ns
{
	// Override me to do something here...
	// 
	// Note: This method is invoked on our bonjour thread.
	
}

/**
 * Called if our bonjour service failed to publish itself.
 * This method does nothing but output a log message telling us about the published service.
**/
- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
	// Override me to do something here...
	// 
	// Note: This method in invoked on our bonjour thread.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is automatically called when a notification of type HTTPConnectionDidDieNotification is posted.
 * It allows us to remove the connection from our array.
**/
- (void)connectionDidDie:(NSNotification *)notification
{
//    NSLog(@"connectionDidDie:%d", [connections count]);
	// Note: This method is called on the connection queue that posted the notification
	[connectionsLock lock];
//    HTTPConnection *con = (HTTPConnection *) [notification object];
//    if ([con numberOfWebSocket] == 0) {
//        [connections removeObject:[notification object]];
//    }
//    for (int i = 0; i < [connections count]; i++) {
//        NSLog(@"connections websocket count:%d", [connections[i] numberOfWebSocket]);
//        if ([connections[i] numberOfWebSocket] == 0) {  //No websocket?
//            [connections removeObjectAtIndex:i];
//        }
//    }
	[connectionsLock unlock];
}

/**
 * This method is automatically called when a notification of type WebSocketDidDieNotification is posted.
 * It allows us to remove the websocket from our array.
**/
- (void)webSocketDidDie:(NSNotification *)notification
{
	// Note: This method is called on the connection queue that posted the notification
	[webSocketsLock lock];
	
	[webSockets removeObject:[notification object]];
	
	[webSocketsLock unlock];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour Thread
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * NSNetService is runloop based, so it requires a thread with a runloop.
 * This gives us two options:
 * 
 * - Use the main thread
 * - Setup our own dedicated thread
 * 
 * Since we have various blocks of code that need to synchronously access the netservice objects,
 * using the main thread becomes troublesome and a potential for deadlock.
**/

static NSThread *bonjourThread;

+ (void)startBonjourThreadIfNeeded
{
	static dispatch_once_t predicate;
	dispatch_once(&predicate, ^{
		
		bonjourThread = [[NSThread alloc] initWithTarget:self
		                                        selector:@selector(bonjourThread)
		                                          object:nil];
		[bonjourThread start];
	});
}

+ (void)bonjourThread
{
	@autoreleasepool {
		// We can't run the run loop unless it has an associated input source or a timer.
		// So we'll just create a timer that will never fire - unless the server runs for 10,000 years.
		
		[NSTimer scheduledTimerWithTimeInterval:[[NSDate distantFuture] timeIntervalSinceNow]
		                                 target:self
		                               selector:@selector(donothingatall:)
		                               userInfo:nil
		                                repeats:YES];
		
		[[NSRunLoop currentRunLoop] run];
	
	}
}

+ (void)executeBonjourBlock:(dispatch_block_t)block
{
	NSAssert([NSThread currentThread] == bonjourThread, @"Executed on incorrect thread");
	
	block();
}

+ (void)performBonjourBlock:(dispatch_block_t)block
{
	[self performSelector:@selector(executeBonjourBlock:)
	             onThread:bonjourThread
	           withObject:block
	        waitUntilDone:YES];
}

@end
