/*
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is DirectHTTPBinaryChannel.
 *
 * The Initial Developer of the Original Code is
 * Anirudh Sasikumar (http://anirudhs.chaosnet.org/).
 * Portions created by the Initial Developer are Copyright (C) 2008
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
*/
/* This class uses lots of code flicked from DirectHTTPChannel.as
 * Copyright (C) 2005 - 2007 Adobe Systems Incorporated. Please see
 * the licensing terms accompanying that file. */
package com.force.http
{
    import flash.events.ErrorEvent;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    
    import mx.core.mx_internal;
    import mx.messaging.MessageAgent;
    import mx.messaging.MessageResponder;
    import mx.messaging.channels.DirectHTTPChannel;
    import mx.messaging.errors.MessageSerializationError;
    import mx.messaging.messages.IMessage;
    
    use namespace mx_internal;
    
    public class DirectHTTPBinaryChannel extends DirectHTTPChannel
    {
        
        public function DirectHTTPBinaryChannel(id:String, uri:String="")
        {
            super(id, uri);
        }
        
        override protected function getMessageResponder(agent:MessageAgent, 
                                                        message:IMessage):MessageResponder
    	{
            return new DirectHTTPBinaryMessageResponder(agent, message, this, new URLLoader());
    	}
        
        override protected function internalSend(msgResp:MessageResponder):void
    	{
            var httpMsgResp:DirectHTTPBinaryMessageResponder = DirectHTTPBinaryMessageResponder(msgResp);
            var urlRequest:URLRequest;
            
            try
            {
                urlRequest = createURLRequest(httpMsgResp.message);
            }
            catch(e: MessageSerializationError)
            {
                httpMsgResp.agent.fault(e.fault, httpMsgResp.message);
                return;
            }
            
            var urlLoader:URLLoader = httpMsgResp.urlLoader;
            urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
            urlLoader.addEventListener(ErrorEvent.ERROR, httpMsgResp.errorHandler);
            urlLoader.addEventListener(IOErrorEvent.IO_ERROR, httpMsgResp.errorHandler);
            urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, httpMsgResp.securityErrorHandler);
            urlLoader.addEventListener(Event.COMPLETE, httpMsgResp.completeHandler);
            urlLoader.load(urlRequest);
    	}
        
    }
    
    
}

/* We wouldn't have had to flick this but for
 * DirectHTTPMessageResponder being a private class */

import flash.events.Event;
import flash.events.ErrorEvent;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.net.URLLoader;
import mx.core.mx_internal;
import mx.messaging.MessageAgent;
import mx.messaging.MessageResponder;
import mx.messaging.channels.DirectHTTPChannel;
import mx.messaging.messages.AcknowledgeMessage;
import mx.messaging.messages.HTTPRequestMessage;
import mx.messaging.messages.ErrorMessage;
import mx.messaging.messages.IMessage;
import mx.resources.IResourceManager;
import mx.resources.ResourceManager;

use namespace mx_internal;

[ResourceBundle("messaging")]

/**
 *  @private
 *  This is an adapter for url loader that is used by the HTTPChannel.
 */
class DirectHTTPBinaryMessageResponder extends MessageResponder
{
    //--------------------------------------------------------------------------
    //
    // Constructor
    // 
    //--------------------------------------------------------------------------    
    
    /**
     *  Constructs a DirectHTTPBinaryMessageResponder.
     */
    public function DirectHTTPBinaryMessageResponder(agent:MessageAgent, msg:IMessage, 
                                                     channel:DirectHTTPChannel, urlLoader:URLLoader)
    {
        super(agent, msg, channel);
        this.urlLoader = urlLoader;
        clientId = channel.clientId;
    }
    
    /**
     *  The URLLoader associated with this responder.
     */
    public var urlLoader:URLLoader;        
    
    private var clientId:String;
    
    /**
     * @private
     */
    private var resourceManager:IResourceManager =
        ResourceManager.getInstance();
    
    //--------------------------------------------------------------------------
    //
    // Methods
    // 
    //--------------------------------------------------------------------------    
    
    /**
     *  @private
     */
    public function errorHandler(event:Event):void
    {
        status(null);
        // send the ack
        var ack:AcknowledgeMessage = new AcknowledgeMessage();
        ack.clientId = clientId;
        ack.correlationId = message.messageId;
        ack.headers[AcknowledgeMessage.ERROR_HINT_HEADER] = true; // hint there was an error
        agent.acknowledge(ack, message);
        // send fault
        var msg:ErrorMessage = new ErrorMessage();
        msg.clientId = clientId;
        msg.correlationId = message.messageId;
        msg.faultCode = "Server.Error.Request";
        msg.faultString = resourceManager.getString(
            "messaging", "httpRequestError");
        var details:String = event.toString();
        if (message is HTTPRequestMessage)
        {
            details += ". URL: ";
            details += HTTPRequestMessage(message).url;
        }
        msg.faultDetail = resourceManager.getString(
            "messaging", "httpRequestError.details", [ details ]);
        msg.rootCause = event;
        agent.fault(msg, message);
    }
    
    /**
     *  @private
     */
    public function securityErrorHandler(event:Event):void
    {
        status(null);
        // send the ack
        var ack:AcknowledgeMessage = new AcknowledgeMessage();
        ack.clientId = clientId;
        ack.correlationId = message.messageId;
        ack.headers[AcknowledgeMessage.ERROR_HINT_HEADER] = true; // hint there was an error
        agent.acknowledge(ack, message);
        // send fault
        var msg:ErrorMessage = new ErrorMessage();
        msg.clientId = clientId;
        msg.correlationId = message.messageId;
        msg.faultCode = "Channel.Security.Error";
        msg.faultString = resourceManager.getString(
            "messaging", "securityError");
        msg.faultDetail = resourceManager.getString(
            "messaging", "securityError.details", [ message.destination ]);
        msg.rootCause = event;
        agent.fault(msg, message);
    }
    
    /**
     *  @private
     */
    public function completeHandler(event:Event):void
    {
        result(null);
        var ack:AcknowledgeMessage = new AcknowledgeMessage();
        ack.clientId = clientId;
        ack.correlationId = message.messageId;
        ack.body = URLLoader(event.target).data;
        agent.acknowledge(ack, message);
    }
    
    /**
     *  Handle a request timeout by closing our associated URLLoader and
     *  faulting the message to the agent.
     */
    override protected function requestTimedOut():void
    {
        urlLoader.removeEventListener(ErrorEvent.ERROR, errorHandler);
        urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
        urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
        urlLoader.removeEventListener(Event.COMPLETE, completeHandler);
        urlLoader.close();
        
        status(null);
        // send the ack
        var ack:AcknowledgeMessage = new AcknowledgeMessage();
        ack.clientId = clientId;
        ack.correlationId = message.messageId;
        ack.headers[AcknowledgeMessage.ERROR_HINT_HEADER] = true; // hint there was an error
        agent.acknowledge(ack, message);
        // send the fault
        agent.fault(createRequestTimeoutErrorMessage(), message);
    }
}
