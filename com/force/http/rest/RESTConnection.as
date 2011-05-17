package com.force.http.rest
{
	import com.force.http.HTTPConnection;
	import com.force.http.rest.RESTRequest;
	import com.force.http.rest.RESTResponse;
	import com.force.oauth.OAuthConnection;
	import com.force.utility.JSON;
	
	import flash.net.URLRequest;
	
	import mx.collections.ArrayCollection;
	import mx.core.UIComponent;
	import mx.messaging.ChannelSet;
	import mx.messaging.messages.IMessage;
	import mx.rpc.AsyncResponder;
	import mx.rpc.IResponder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.rpc.http.HTTPService;
	import mx.utils.ObjectProxy;
	import mx.utils.ObjectUtil;
	
	
	public class RESTConnection
	{
		private var _oauth:Object;
		private var lastRequestDate:Date;
		private var pendingRequests:ArrayCollection = new ArrayCollection();
		private var refreshTokenCallback:IResponder = new mx.rpc.Responder(refreshTokenResult,refreshTokenError);
		
		public var api:String = "21.0";
		public var oauthConnection:OAuthConnection;
		
		public function RESTConnection() {
			
		}
		
		public function setSession(session:String, server:String):void {
			this.oauth = {access_token: session, instance_url: server};
		}
		
		public function set oauth(result:Object):void
		{
			trace(ObjectUtil.toString(result));
			_oauth = result;
			if(result.id != null) {_oauth["userId"] = result.id.split("/")[5];}
			_oauth["lastRequestDate"] = new Date();
			
			if(_oauth.refresh_token != null) {trace("REFRESH TOKEN:::::::::::::"+_oauth.refresh_token);}
			trace(ObjectUtil.toString(_oauth));
			
		}
		
		public function get oauth():Object {
			return _oauth;
		}
		
		public function refreshTokenResult(result:Object):void {
			oauth.access_token = result.access_token;
			oauth["lastRequestDate"] = new Date();
			sendPendingRequests();
			
			trace("REFRESH TOKEN:::::::::::::"+_oauth.refresh_token);
			trace(ObjectUtil.toString(_oauth));
			
			
		}
		
		public function refreshTokenError(error:Object):void {
			trace(error);
		}
		
		public function sendPendingRequests():void {
			trace("PENDING REQUESTS::::"+pendingRequests.length);
			for(var i:int=0; i < pendingRequests.length; i++) {
				var params:Array = pendingRequests[i].params;
				if(pendingRequests[i].type == 'query') { this.query(params[0],params[1]); }
				if(pendingRequests[i].type == 'create') { this.create(params[0],params[1],params[2]); }
				if(pendingRequests[i].type == 'update') { this.update(params[0],params[1],params[2],params[3]); }
				if(pendingRequests[i].type == 'getObjectById') { this.getObjectById(params[0],params[1],params[2]); }
				if(pendingRequests[i].type == 'getObjectByURI') { this.getObjectByURI(params[0],params[1]); }
				if(pendingRequests[i].type == 'getFileByURI') { this.getFileByURI(params[0],params[1]); }
			}
			
			pendingRequests = new ArrayCollection();
		}
		
		public function tokenExpired():Boolean {
			if((new Date().getTime() - oauth.lastRequestDate.getTime()) > 600000) {
				//	if((new Date().getTime() - oauth.lastRequestDate.getTime()) > 30000) { //30 secs?
				trace("token expired");
				return true;
			} 
			return false;
		}
		
		private function refreshOAuth():void {
			this.oauthConnection.login(null,refreshTokenCallback,true);
			trace(ObjectUtil.toString(oauth));
			this.oauthConnection.getRefreshToken(oauth);
			trace("new token request sent");
		}
		
		public function query(soql:String, _callback:IResponder):void {
			if(tokenExpired()) {
				pendingRequests.addItem(new RESTRequest("query",[soql,_callback]));
				trace("sending new request");
				if(pendingRequests.length == 1) {
					refreshOAuth();
				}
				return;
			}
			
			var headers:Object = new Object();
			var method:String = "GET";
			
			headers = new Object();
			headers["Authorization"] = "OAuth "+oauth.access_token;
			headers["Accept"] = "application/jsonrequest";
			var url:String = oauth.instance_url + "/services/data/v"+api+"/query?q="+soql;
			
			var response:RESTResponse = new RESTResponse(_callback);
			var httpCallback:IResponder = new mx.rpc.Responder(response.resultHandler,response.faultHandler);
			HTTPConnection.send(headers,method,url,httpCallback);
			trace("Query sent:"+soql);
		}
		
		public function create(created:Object, type:String, _callback:IResponder):void {
			if(tokenExpired()) {
				pendingRequests.addItem(new RESTRequest("create",[created,type,_callback]));
				trace("sending new request");
				if(pendingRequests.length == 1) {
					
				}
				return;
			}
			
			var headers:Object = new Object();
			var method:String = "POST";
			
			trace("creating create");
			
			headers = new Object();
			headers["Authorization"] = "OAuth "+oauth.access_token;
			headers["Accept"] = "application/jsonrequest";
			var url:String = oauth.instance_url + "/services/data/v"+api+"/sobjects/"+type+"/";
			
			var response:RESTResponse = new RESTResponse(_callback);
			var httpCallback:IResponder = new mx.rpc.Responder(response.resultHandler,response.faultHandler);
			HTTPConnection.send(headers,method,url,httpCallback,false,JSON.serialize(created),false);
			trace("Create sent:"+JSON.serialize(created));
		}
		
		public function update(updated:Object, id:String, type:String, _callback:IResponder):void {
			if(tokenExpired()) {
				pendingRequests.addItem(new RESTRequest("update",[updated,id,type,_callback]));
				trace("sending new request");
				if(pendingRequests.length == 1) {
					refreshOAuth();
				}
				return;
			}
			
			var headers:Object = new Object();
			var method:String = "POST";
			trace("creating update");
			
			headers = new Object();
			headers["Authorization"] = "OAuth "+oauth.access_token;
			headers["Accept"] = "application/jsonrequest";
			var url:String = oauth.instance_url + "/services/data/v"+api+"/sobjects/"+type+"/"+id;
			
			var response:RESTResponse = new RESTResponse(_callback);
			var httpCallback:IResponder = new mx.rpc.Responder(response.resultHandler,response.faultHandler);
			HTTPConnection.send(headers,method,url+"?_HttpMethod=PATCH",httpCallback,false,JSON.serialize(updated),false);
			trace("Updated sent:"+JSON.serialize(updated));
		}
		
		public function getObjectById(type:String, id:String, _callback:IResponder):void {
			if(tokenExpired()) {
				pendingRequests.addItem(new RESTRequest("getObjectById",[type,id,_callback]));
				trace("sending new request");
				if(pendingRequests.length == 1) {
					refreshOAuth();
				}
				return;
			}
			
			var headers:Object = new Object();
			var method:String = "GET";
			
			headers = new Object();
			headers["Authorization"] = "OAuth "+oauth.access_token;
			headers["Accept"] = "application/jsonrequest";
			var url:String = oauth.instance_url + "/services/data/v"+api+"/sobjects/"+type+"/"+id;
			
			var response:RESTResponse = new RESTResponse(_callback);
			var httpCallback:IResponder = new mx.rpc.Responder(response.resultHandler,response.faultHandler);
			HTTPConnection.send(headers,method,url,httpCallback);
			trace("Query sent");
		}
		
		
		
		public function getObjectByURI(uri:String, _callback:IResponder):void {
			if(tokenExpired()) {
				pendingRequests.addItem(new RESTRequest("getObjectByURI",[uri,_callback]));
				trace("sending new request");
				if(pendingRequests.length == 1) {
					refreshOAuth();
				}
				return;
			}
			
			var headers:Object = new Object();
			var method:String = "GET";
			
			headers = new Object();
			headers["Authorization"] = "OAuth "+oauth.access_token;
			headers["Accept"] = "application/jsonrequest";
			var url:String = oauth.instance_url + uri;
			
			var response:RESTResponse = new RESTResponse(_callback);
			var httpCallback:IResponder = new mx.rpc.Responder(response.resultHandler,response.faultHandler);
			HTTPConnection.send(headers,method,url,httpCallback);
			trace("Query sent");
		}
		
		public function getFileByURI(uri:String, _callback:IResponder):void {
			if(tokenExpired()) {
				pendingRequests.addItem(new RESTRequest("getFileByURI",[uri,_callback]));
				trace("sending new request");
				if(pendingRequests.length == 1) {
					refreshOAuth();
				}
				return;
			}
			
			var headers:Object = new Object();
			var method:String = "GET";
			
			headers = new Object();
			headers["Authorization"] = "OAuth "+oauth.access_token;
			headers["Accept"] = "application/jsonrequest";
			var url:String = oauth.instance_url + uri;
			
			var response:RESTResponse = new RESTResponse(_callback);
			var httpCallback:IResponder = new mx.rpc.Responder(response.resultHandler,response.faultHandler);
			HTTPConnection.send(headers,method,url,httpCallback,true);
			trace("Query sent");
		}
		
		/* Currently not supported by the Flash Player */
		
	/*	public function deleteObjectById(type:String, id:String, _callback:IResponder):void {
			if(tokenExpired()) {
				pendingRequests.addItem(new RESTRequest("deleteObjectById",[type,id,_callback]));
				trace("sending new request");
				if(pendingRequests.length == 1) {
					refreshOAuth();
				}
				return;
			}
			
			
		} */
		
		
		
		private function genericError(a:Object, token:Object):void {
			trace("Error:"+ObjectUtil.toString(a));
		}
		
		
		
	}
}