package com.force.http
{
	import mx.core.UIComponent;
	import mx.messaging.ChannelSet;
	import mx.rpc.IResponder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.rpc.http.HTTPService;
	import mx.utils.ObjectUtil;
	
	import com.force.http.DirectHTTPBinaryChannel;
	
	public class HTTPConnection
	{	
		
		public function HTTPConnection()
		{
		
		}
		
		public static function send(headers:Object, method:String, uri:String, callback:IResponder, isBinary:Boolean = false, postObject:Object = null, isSoap:Boolean = false):void {
			var http:HTTPService = new HTTPService();
			http.method = method;
			http.headers = headers;
			http.url = uri;
			
			http.addEventListener( ResultEvent.RESULT, callback.result );
			http.addEventListener( FaultEvent.FAULT, callback.fault );
			
			if(isBinary) {
				http.resultFormat = "e4x";
				var dcs:ChannelSet = new ChannelSet();
				var binaryChannel:DirectHTTPBinaryChannel = new DirectHTTPBinaryChannel("direct_http_binary_channel");
				dcs.addChannel(binaryChannel);            
				http.channelSet = dcs;
			}
			
			if(postObject != null) { 
				if(typeof(postObject) == "string") { http.contentType = "application/json; charset=UTF-8"; }
				http.send(postObject); trace("Sent "+postObject); 
			}
			else {
				http.send();
			}
			
			trace("sent");
			
		}
	}
}