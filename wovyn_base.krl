ruleset wovyn_base {

    meta {
        shares __testing
        use module sensor_profile alias profile
        use module twilio_lesson_keys
        use module twilio_m alias twilio
            with account_sid = keys:twilio{"account_sid"}
                auth_token =  keys:twilio{"auth_token"}
        
    }

    global {
        __testing = { "queries": [],
            "events":  
            [ 
                { 
                    "domain": "wovyn", "type": "fakeheartbeat", "attrs": [ "temperature" ] 
                }
            ] 
        }
    }

    rule process_heartbeat {
        select when wovyn:heartbeat genericThing re#(.+)#
        pre {
            temp = event:attr("genericThing").get("data").get("temperature").head()

        }
        send_directive("test", {"hello": "world"})
        fired {
            raise wovyn event "new_temperature_reading"
                attributes {"temperature":temp.get("temperatureF"), "timestamp":time:now()}
        }
    }

    rule process_fake_heartbeat {
        select when wovyn:fakeheartbeat
        pre {
            temp = event:attr("temperature")

        }
        send_directive("test", {"hello": "world"})
        fired {
            raise wovyn event "new_temperature_reading"
                attributes {"temperature":temp, "timestamp":time:now()}
        }
    }

    rule find_high_temps {
        select when wovyn:new_temperature_reading
        pre {
            temperature = event:attr("temperature")
            is_violation = (temperature > profile:get_threshold()) 
                => true | false
        }
        send_directive("temp_reading", {"is_violation": is_violation})
        fired {
            raise wovyn event "threshold_violation" 
                attributes {"temperature": temperature,"timestamp": event:attr("timestamp") , "threshold": temperature_threshold}
                if is_violation
        }
    }

    rule threshold_notification {
        select when wovyn:threshold_violation
        pre {
            message = "The current temperature of " + 
                event:attr("temperature") +
                " has violated the threshold of " +
                event:attr("threshold") +
                " at " +
                event:attr("timestamp") + 
                "."
        }
        twilio:send_sms(profile:get_full_phone_number(),
                       "+12029911769",
                       message)
    }
}