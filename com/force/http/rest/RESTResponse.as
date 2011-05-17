package com.force.http.rest
{
	import mx.rpc.IResponder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.ObjectUtil;
	
	import com.force.utility.JSON;
	
	public class RESTResponse
	{
		public var callback:IResponder;
		
		public function RESTResponse(_callback:IResponder)
		{
			this.callback = _callback;
		}
		
		public function resultHandler(event:ResultEvent):void {
			var result:Object;
			trace(typeof(event.result));
			trace(ObjectUtil.toString(event.result));
			
			try {
				switch(typeof(event.result)) {
					case "object": 
						this.callback.result(event.result); //probably a file, let's just send it back
						return;
					case "string": 
						if(event.result.toString() == "") {
							this.callback.result(new Object());
							return;
						}
						
						/*Strange */
						if(event.result.indexOf("Session expired or invalid") >= 0) {
							this.callback.fault({message:"Session expired or invalid"});
							return;
						}
						
						result = JSON.deserialize(event.result.toString()); //probably JSON, let's pull the records into a JSON object and send bac
						if(result.records != null) {result = result.records;}
						this.callback.result(result);
				}
			} catch(e:Error) {
				trace("Error Message:"+e.message);
			}	
		}
		
		public function faultHandler(event:FaultEvent):void {
			trace('Error!!');
			trace(event.fault.faultString);
			trace(ObjectUtil.toString(event));
			this.callback.fault(event.fault);
		}
	}
}