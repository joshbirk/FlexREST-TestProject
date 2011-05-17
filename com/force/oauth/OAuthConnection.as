package com.force.oauth
{
	import com.force.http.HTTPConnection;
	import com.force.utility.JSON;
	
	import flash.display.DisplayObject;
	import flash.display.Stage;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.geom.Rectangle;
	import flash.html.HTMLLoader;
	import flash.net.SharedObject;
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	
	import mx.rpc.IResponder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.rpc.http.HTTPService;
	import mx.utils.ObjectUtil;
	
	public class OAuthConnection
	{
		protected var publicKey:String; 
		protected var privateKey:String;
		protected var redirectURI:String; 
		protected var oauthURI:String = "https://login.salesforce.com";
		
		public var oauthView:DisplayObject;
		
		
		protected var jsonStorage:SharedObject = SharedObject.getLocal("results");
		protected var oauthToken:String;
		
		protected var callback:IResponder;
		
		public function OAuthConnection(_publicKey:String, _privateKey:String, _redirectURI:String):void {
			this.publicKey = _publicKey;
			this.privateKey = _privateKey;
			this.redirectURI = _redirectURI;
		}
		
		public function login(Stage:flash.display.Stage = null, responder:IResponder = null, refresh:Boolean = false):void {
			this.callback = responder;
			
			if(!refresh && tokenResult != null) {
				trace('Refreshing with: \n '+ObjectUtil.toString(tokenResult));
				if( (Date.parse(new Date()) - tokenResult.issued_at) - 600000) { //token is 10 minutes old, get a new one
					this.refresh();
				} else {
					responder.result(tokenResult);
				}
				
				removeBrowser();
				return;
			}
			
			if(refresh) { 
				this.refresh();
				return;
			}
			
			
			if(Stage == null) { return; }
			trace("Creating browser");
			var rect:Rectangle = new Rectangle(Stage.width/2 - 240,Stage.height/2 - 240,480,480);
			if(this.oauthView == null) {
				this.oauthView = new HTMLLoader();
				this.oauthView.addEventListener(Event.LOCATION_CHANGE,getToken);
				this.oauthView.height = rect.height;
				this.oauthView.width = rect.width;
				this.oauthView.x = rect.x;
				this.oauthView.y = rect.y;
				Stage.addChild(this.oauthView);
			}
			var url:URLRequest = new URLRequest(oauthURI+"/services/oauth2/authorize?display=touch&response_type=code&client_id="+publicKey+"&redirect_uri="+redirectURI);
			HTMLLoader(this.oauthView).load(url);
		}
		
		public function removeBrowser():void {
			if(this.oauthView != null && this.oauthView.parent != null) {
				this.oauthView.parent.removeChild(this.oauthView);
			}
		}
		
		public function get tokenResult():Object {
			return JSON.deserialize(jsonStorage.data.jsonResult);
		}
		
		public function set tokenResult(result:Object):void {
			var refresh_token:String;
			if(tokenResult.refresh_token != null) { 
				refresh_token = tokenResult.refresh_token;
			}
			if(refresh_token != null) {
				result.refresh_token = refresh_token;
			}
			jsonStorage.data.jsonResult = JSON.serialize(result);
		}
		
		public static function SOAPLoginRequest():Object {
			if(SharedObject.getLocal("results").data.jsonResult != null) {
				var tokenResult:Object = JSON.deserialize(SharedObject.getLocal("results").data.jsonResult);
				var pod:String = tokenResult.instance_url.split(".")[0];
				pod = pod.replace("https://","");
				var orgId:String = tokenResult.id.split("/")[5];
				
				var lr:Object = {
					session_id : tokenResult.access_token,
						server_url : 'https://c.'+pod+'.visual.force.com/services/Soap/u/21.0/'+orgId
				};
				
				return lr;
				
			}
			
			return null;
		}
		
		public function refresh():Boolean {
			if(tokenResult != null && tokenResult.refresh_token != null) {
				getRefreshToken(tokenResult);
				return true;
			} else {
				callback.fault({message:"No Refresh Token"});
				return false;
			}
		}
		
		
		
		public static function clearAccess():void {
			var jsonStorage:SharedObject = SharedObject.getLocal("results");
			jsonStorage.data.jsonResult = null;
		}
		
		protected function getToken(event:Event):void {
			if(HTMLLoader(oauthView).location.indexOf("code=") < 0) {
				return;
			}
			
			var requestToken:String = unescape(HTMLLoader(oauthView).location.substring(HTMLLoader(oauthView).location.indexOf("code=")+5, HTMLLoader(oauthView).location.length));
			removeBrowser();			
			
			getAccessToken(requestToken);
			
		}
		
		public function getAccessToken(requestToken:String):void {		
			var headers:Object = new Object();
			var method:String  = "POST";
			headers["code"] = requestToken;
			headers["grant_type"] = "authorization_code";
			headers["client_id"] = publicKey;
			headers["client_secret"] = privateKey;
			headers["redirect_uri"] = redirectURI;
			headers["Accept"] = "application/jsonrequest";
			headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
			var url:String = oauthURI + "/services/oauth2/token";
			var callback:IResponder = new mx.rpc.Responder(resultHandler,faultHandler);
			
			HTTPConnection.send(headers,"POST",url,callback,false,headers,false);
		}
		
		public function getRefreshToken(oauthResult:Object):void {		
			trace("getting new refresh token");
			var headers:Object = new Object();
			var method:String  = "POST";
			headers["refresh_token"] = oauthResult.refresh_token;
			headers["grant_type"] = "refresh_token";
			headers["client_id"] = publicKey;
			headers["client_secret"] = privateKey;
			headers["redirect_uri"] = redirectURI;
			headers["Accept"] = "application/jsonrequest";
			headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
			var url:String = oauthURI + "/services/oauth2/token";
			var callback:IResponder = new mx.rpc.Responder(resultHandler,faultHandler);
			
			HTTPConnection.send(headers,"POST",url,callback,false,headers,false);
			
		}
		
		private function resultHandler(event:ResultEvent):void {
			var json:Object;
			trace("RESULT::"+ObjectUtil.toString(event));
			
			if(event.result.toString().indexOf("Session expired or invalid") >= 0) {
				if(!refresh()) {
					clearAccess();
					this.callback.fault({message:'Reset OAuth Connection'});
				}
			}
			
			trace("JSON Response::"+event.result.toString());
			json = JSON.deserialize(event.result.toString());
			trace("JSON Token::"+json.access_token);
			if(tokenResult == null) {jsonStorage.data.jsonResult = event.result.toString();}
			else {
				tokenResult = json;
				trace("TokenResult Access Token Updated::"+tokenResult.access_token);
			}
			if(json == null) {
				clearAccess();
				this.callback.fault({message:'Reset OAuth Connection'});
			}
			
			this.callback.result(json);
			removeBrowser();
		}
		
		private function faultHandler(event:FaultEvent):void {
			trace(ObjectUtil.toString(event));
			if(event.fault.faultDetail != null) {this.callback.fault(event.fault.faultDetail);}
			removeBrowser();
		}
	}
}