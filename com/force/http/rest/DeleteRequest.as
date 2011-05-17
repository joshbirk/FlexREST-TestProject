package com.force.http.rest
{
	import com.adobe.net.URI;
	import com.force.http.rest.RESTConnection;
	
	import org.httpclient.HttpClient;
	import org.httpclient.HttpRequest;
	import org.httpclient.events.HttpListener;
	import org.httpclient.http.Delete;
	
	import mx.rpc.IResponder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.ObjectUtil;
	
	
	/* Requires as3httpclientlib, as3corelib and as3crypto */
	
	public class DeleteRequest
	{
		public var rest:RESTConnection;
		
		public function DeleteRequest(_rest:RESTConnection):void
		{
			rest = _rest;
		}
		
		public function deleteObject(id:String,type:String,_callback:IResponder):void {
			var headers:Object = new Object();
			var method:String = "DELETE";
			var req:HttpRequest = new Delete();
			
			req.addHeader("Authorization","OAuth "+rest.oauth.access_token);
			var url:String = rest.oauth.instance_url + "/services/data/v"+rest.api+"/sobjects/"+type+"/"+id;
			var client:HttpClient = new HttpClient();  
			
			var httpListener:HttpListener = new HttpListener();
			httpListener.onComplete = _callback.result;
			httpListener.onError = _callback.fault;
			
			var uri:URI = new URI(url);
			client.request(uri,req,-1,httpListener);
			
			
			
			trace("Sent delete request for:"+id);
			trace(url);
		}
	}
}