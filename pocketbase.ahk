#Requires AutoHotkey v2.0

__ObjHas(this, key) {
    return this.HasOwnProp(key)
}
Object.Prototype.DefineProp('Has', {Call: __ObjHas})
__ObjGet(this, key) {
    return this.GetOwnPropDesc(key).Value
}
Object.Prototype.DefineProp('__Item', {Call: __ObjGet})

class Pocketbase {
    DEBUG := 'DEBUG'
    INFO := 'INFO'
    WARN := 'WARN'
    ERROR := 'ERROR'
    FATAL := 'FATAL'

    /**
     * @description Create a new PocketBase instance
     * @param host {String} Root URL of your PocketBase instance
     * @param user {String} Email of the user to authenticate
     * @param pwd {String} Password of the user to authenticate
     * @param useMap {Boolean} Use Map instead of Object
     * @param logCallback {Function} Callback to log messages
     */
    __New(host, user, pwd, useMap := true, logCallback := '') {
        this.host := host
        this.user := user
        this.pwd := pwd
        this.useMap := useMap
        this.logCallback := logCallback
        this.__log(this.DEBUG, 'PocketBase instance created')
        this.Authenticate()
        this.__log(this.DEBUG, 'PocketBase instance authenticated as ' this.user)
    }
    __log(level, msg) {
        if this.logCallback {
            this.logCallback.Call(level, msg)
        }
    }

    /**
     * @description Refresh the token
     */
    AuthRefresh() {
        this.__log(this.DEBUG, 'Trying to refresh token')
        if !this.token {
            this.__log(this.ERROR, 'Token not set. Authenticate first')
            Throw Error('Token not set', -2)
        }
        headers := Map('Authorization', this.token)
        this.__log(this.DEBUG, 'Headers set')
        url := this.host '/api/collections/users/auth-refresh'
        this.__log(this.DEBUG, 'Requesting ' url)
        response := __JSON.parse(this.__Request(url, 'POST', headers),, this.useMap)

        if !response.Has('token') != 200 {
            this.__log(this.ERROR, 'Error on AuthRefresh')
            try {
                this.__log(this.DEBUG, 'Trying to authenticate again')
                this.Authenticate()
                this.__log(this.DEBUG, 'Authenticate again done')
            } catch Error as e {
                this.__log(this.ERROR, 'Failed to authenticate again')
                Throw Error(e.Message, -2)
            }
        }

        this.token := response['token']
        this.userRecord := response['record']
        this.__log(this.DEBUG, 'Token set')
    }

    /**
     * @description Authenticate the user
     */
    Authenticate() {
        this.__log(this.DEBUG, 'Authenticating')
        body := Map('identity', this.user, 'password', this.pwd)
        this.__log(this.DEBUG, 'Body set')
        url := this.host '/api/collections/users/auth-with-password'
        this.__log(this.DEBUG, 'Requesting ' url)
        response := __JSON.parse(this.__Request(url, 'POST',, body),, this.useMap)
        
        if response.Has('status') and response['status'] == 404 {
            this.__log(this.ERROR, 'Code 404 Not Found. Host: ' url)
            Throw Error('Code 404 Not Found. Host: ' url, -2)
        }
        if response.Has('status') and response['status'] == 400 {
            this.__log(this.ERROR, 'Code 400. ' response['message'])
            Throw Error('Code 400. ' response['message'], -2)
        }

        this.token := response['token']
        this.userRecord := response['record']
        this.__log(this.DEBUG, 'Token set')
    }

    /**
     * 
     * @param collection {String} Name of the collection
     * @param page {String} Page number
     * @param perPage {String} Number of items per page
     * @param sort {String} Columns to sort. Ex: "-created,id" <- DESC created, ASC id
     * @param filter {String} Filter the results like it were an IF statement. Ex: "created > '2022-01-01'" or "(created = '2022-01-01' AND id > 1)"
     * @param expand {String} Auto expands record rellations. Ex: "relField1,relField2.subRelField"
     * @param fields {String} Comma separated list of fields to return. Ex: "id,name,created"
     * @param skipTotal {String} Skip the total count
     */
    ListCollection(collection, page?, perPage?, sort?, filter?, expand?, fields?, skipTotal?) {
        this.__log(this.DEBUG, 'ListCollection')
        page := page ?? ''
        perPage := perPage ?? ''
        sort := sort ?? ''
        filter := filter ?? ''
        expand := expand ?? ''
        fields := fields ?? ''
        skipTotal := skipTotal ?? ''

        query := ''
        if page != '' {
            query .= '?page=' page
        }
        if perPage != '' {
            query .= '?perPage=' perPage
        }
        if sort != '' {
            query .= '?sort=' sort
        }
        if filter != '' {
            query .= '?filter=' filter
        }
        if expand != '' {
            query .= '?expand=' expand
        }
        if fields != '' {
            query .= '?fields=' fields
        }
        if skipTotal != '' {
            query .= '?skipTotal=' skipTotal
        }
        url := this.host '/api/collections/' collection '/records' query
        this.__log(this.DEBUG, 'Requesting ' url)
        response := __JSON.parse(this.__Request(url, 'GET', Map('Authorization', this.token)),, this.useMap)

        if !response.Has('items') {
            this.__log(this.ERROR, 'Error on ListCollection')
            try {
                this.__log(this.DEBUG, 'Trying to authenticate again')
                this.AuthRefresh()
                response := __JSON.parse(this.__Request(url, 'GET', Map('Authorization', this.token)),, this.useMap)
                this.__log(this.DEBUG, 'Authenticate again done')
            } catch Error as e {
                this.__log(this.ERROR, 'Failed to authenticate again')
                Throw Error('Code ' response['status'] ' ' response.Has('message') ? response['message'] : '', -2)
            }
        }
        return response
    }

    /**
     * 
     * @param collection {String} Name of the collection
     * @param id {String} Id of the record
     * @param expand {String} Auto expands record rellations. Ex: "relField1,relField2.subRelField"
     * @param fields {String} Comma separated list of fields to return. Ex: "id,name,created"
     */
    GetById(collection, id, expand?, fields?) {
        this.__log(this.DEBUG, 'GetById')
        expand := expand ?? ''
        fields := fields ?? ''
        query := ''
        if expand != '' {
            query .= '?expand=' expand
        }
        if fields != '' {
            query .= '?fields=' fields
        }
        url := this.host '/api/collections/' collection '/records/' id query
        this.__log(this.DEBUG, 'Requesting ' url)
        response := __JSON.parse(this.__Request(url, 'GET', Map('Authorization', this.token)),, this.useMap)
        if !response.Has('collectionId') {
            this.__log(this.ERROR, 'Error on GetById')
            try {
                this.__log(this.DEBUG, 'Trying to authenticate again')
                this.AuthRefresh()
                response := __JSON.parse(this.__Request(url, 'GET', Map('Authorization', this.token)),, this.useMap)
                this.__log(this.DEBUG, 'Authenticate again done')
            } catch Error as e {
                this.__log(this.ERROR, 'Failed to authenticate again')
                Throw Error('Code ' response['status'] ' ' response.Has('message') ? response['message'] : '', -2)
            }
        } 
        return response
    }

    /**
     * 
     * @param collection {String} Name of the collection
     * @param data {Map} Data to create
     * @param expand {String} Auto expands record rellations. Ex: "relField1,relField2.subRelField"
     * @param fields {String} Comma separated list of fields to return. Ex: "id,name,created"
     */
    Create(collection, data := Map(), expand?, fields?) {
        this.__log(this.DEBUG, 'Create')
        expand := expand ?? ''
        fields := fields ?? ''
        query := ''
        if expand != '' {
            query .= '?expand=' expand
        }
        if fields != '' {
            query .= '?fields=' fields
        }
        url := this.host '/api/collections/' collection '/records' query
        this.__log(this.DEBUG, 'Requesting ' url)
        response := __JSON.parse(this.__Request(url, 'POST', Map('Authorization', this.token), data),, this.useMap)
        if !response.Has('collectionId') {
            this.__log(this.ERROR, 'Error on Create')
            try {
                this.__log(this.DEBUG, 'Trying to authenticate again')
                this.AuthRefresh()
                response := __JSON.parse(this.__Request(url, 'POST', Map('Authorization', this.token), data),, this.useMap)
                this.__log(this.DEBUG, 'Authenticate again done')
            } catch Error as e {
                this.__log(this.ERROR, 'Failed to authenticate again')
                Throw Error('Code ' response['status'] ' ' response.Has('message') ? response['message'] : '', -2)
            }
        } 
        return response
    }

    /**
     * 
     * @param collection {String} Name of the collection
     * @param id {String} Id of the record
     * @param data {Map} Data to update
     * @param expand {String} Auto expands record rellations. Ex: "relField1,relField2.subRelField"
     * @param fields {String} Comma separated list of fields to return. Ex: "id,name,created"
     */
    Update(collection, id, data := Map(), expand?, fields?) {
        this.__log(this.DEBUG, 'Update')
        expand := expand ?? ''
        fields := fields ?? ''
        query := ''
        if expand != '' {
            query .= '?expand=' expand
        }
        if fields != '' {
            query .= '?fields=' fields
        }
        url := this.host '/api/collections/' collection '/records/' id query
        this.__log(this.DEBUG, 'Requesting ' url)
        response := __JSON.parse(this.__Request(url, 'PATCH', Map('Authorization', this.token), data),, this.useMap)
        if !response.Has('collectionId') {
            this.__log(this.ERROR, 'Error on Update')
            try {
                this.__log(this.DEBUG, 'Trying to authenticate again')
                this.AuthRefresh()
                response := __JSON.parse(this.__Request(url, 'PATCH', Map('Authorization', this.token), data),, this.useMap)
                this.__log(this.DEBUG, 'Authenticate again done')
            } catch Error as e {
                this.__log(this.ERROR, 'Failed to authenticate again')
                Throw Error('Code ' response['status'] ' ' response.Has('message') ? response['message'] : '', -2)
            }
        } 
        return response
    }

    /**
     * 
     * @param collection {String} Name of the collection
     * @param id {String} Id of the record
     */
    Delete(collection, id) {
        this.__log(this.DEBUG, 'Delete')
        url := this.host '/api/collections/' collection '/records/' id
        this.__log(this.DEBUG, 'Requesting ' url)
        response := __JSON.parse(this.__Request(url, 'DELETE', Map('Authorization', this.token)),, this.useMap)
        if response.Has('code') {
            this.__log(this.ERROR, 'Error on Delete')
            try {
                this.__log(this.DEBUG, 'Trying to authenticate again')
                this.AuthRefresh()
                response := __JSON.parse(this.__Request(url, 'DELETE', Map('Authorization', this.token)),, this.useMap)
                this.__log(this.DEBUG, 'Authenticate again done')
            } catch Error as e {
                this.__log(this.ERROR, 'Failed to authenticate again')
                Throw Error('Code ' response['status'] ' ' response.Has('message') ? response['message'] : '', -2)
            }
        } 
        return response
    }
    /*
    ListCollections() {
        headers := Map('Authorization', this.token)
        url := this.host '/api/collections'
        response := __JSON.parse(this.__Request(url, 'GET', headers))
        if !response.Has('status') or !response.Has('message') {
            Throw Error('Error on list collections', -2)
        }
        if response['status'] != 200 {
            Throw Error('Code ' response['status'] . ' ' response['message'], -2)
        }
        return response
    }
    */

    __Request(url, method := 'POST', headers := Map(), body := Map(), contentType := 'application/json') {
        req := ComObject('WinHttp.WinHttpRequest.5.1')
        req.Open(method, url, true)
        req.SetRequestHeader('Content-Type', contentType)

        for header, value in headers {
            req.SetRequestHeader(header, value)
        }
        
        body := __JSON.stringify(body)
        req.Send(body)
        req.WaitForResponse()
        return req.ResponseText
    }
}


; JSON library from https://github.com/thqby/ahk2_lib/blob/master/JSON.ahk

/************************************************************************
 * @description: JSON格式字符串序列化和反序列化, 修改自[HotKeyIt/Yaml](https://github.com/HotKeyIt/Yaml)
 * 增加了对true/false/null类型的支持, 保留了数值的类型
 * @author thqby, HotKeyIt
 * @date 2024/02/24
 * @version 1.0.7
 ***********************************************************************/

class __JSON {
	static null := ComValue(1, 0), true := ComValue(0xB, 1), false := ComValue(0xB, 0)

	/**
	 * Converts a AutoHotkey Object Notation JSON string into an object.
	 * @param text A valid JSON string.
	 * @param keepbooltype convert true/false/null to JSON.true / JSON.false / JSON.null where it's true, otherwise 1 / 0 / ''
	 * @param as_map object literals are converted to map, otherwise to object
	 */
	static parse(text, keepbooltype := false, as_map := true) {
		keepbooltype ? (_true := this.true, _false := this.false, _null := this.null) : (_true := true, _false := false, _null := "")
		as_map ? (map_set := (maptype := Map).Prototype.Set) : (map_set := (obj, key, val) => obj.%key% := val, maptype := Object)
		NQ := "", LF := "", LP := 0, P := "", R := ""
		D := [C := (A := InStr(text := LTrim(text, " `t`r`n"), "[") = 1) ? [] : maptype()], text := LTrim(SubStr(text, 2), " `t`r`n"), L := 1, N := 0, V := K := "", J := C, !(Q := InStr(text, '"') != 1) ? text := LTrim(text, '"') : ""
		Loop Parse text, '"' {
			Q := NQ ? 1 : !Q
			NQ := Q && RegExMatch(A_LoopField, '(^|[^\\])(\\\\)*\\$')
			if !Q {
				if (t := Trim(A_LoopField, " `t`r`n")) = "," || (t = ":" && V := 1)
					continue
				else if t && (InStr("{[]},:", SubStr(t, 1, 1)) || A && RegExMatch(t, "m)^(null|false|true|-?\d+(\.\d*(e[-+]\d+)?)?)\s*[,}\]\r\n]")) {
					Loop Parse t {
						if N && N--
							continue
						if InStr("`n`r `t", A_LoopField)
							continue
						else if InStr("{[", A_LoopField) {
							if !A && !V
								throw Error("Malformed JSON - missing key.", 0, t)
							C := A_LoopField = "[" ? [] : maptype(), A ? D[L].Push(C) : map_set(D[L], K, C), D.Has(++L) ? D[L] := C : D.Push(C), V := "", A := Type(C) = "Array"
							continue
						} else if InStr("]}", A_LoopField) {
							if !A && V
								throw Error("Malformed JSON - missing value.", 0, t)
							else if L = 0
								throw Error("Malformed JSON - to many closing brackets.", 0, t)
							else C := --L = 0 ? "" : D[L], A := Type(C) = "Array"
						} else if !(InStr(" `t`r,", A_LoopField) || (A_LoopField = ":" && V := 1)) {
							if RegExMatch(SubStr(t, A_Index), "m)^(null|false|true|-?\d+(\.\d*(e[-+]\d+)?)?)\s*[,}\]\r\n]", &R) && (N := R.Len(0) - 2, R := R.1, 1) {
								if A
									C.Push(R = "null" ? _null : R = "true" ? _true : R = "false" ? _false : IsNumber(R) ? R + 0 : R)
								else if V
									map_set(C, K, R = "null" ? _null : R = "true" ? _true : R = "false" ? _false : IsNumber(R) ? R + 0 : R), K := V := ""
								else throw Error("Malformed JSON - missing key.", 0, t)
							} else {
								; Added support for comments without '"'
								if A_LoopField == '/' {
									nt := SubStr(t, A_Index + 1, 1), N := 0
									if nt == '/' {
										if nt := InStr(t, '`n', , A_Index + 2)
											N := nt - A_Index - 1
									} else if nt == '*' {
										if nt := InStr(t, '*/', , A_Index + 2)
											N := nt + 1 - A_Index
									} else nt := 0
									if N
										continue
								}
								throw Error("Malformed JSON - unrecognized character.", 0, A_LoopField " in " t)
							}
						}
					}
				} else if A || InStr(t, ':') > 1
					throw Error("Malformed JSON - unrecognized character.", 0, SubStr(t, 1, 1) " in " t)
			} else if NQ && (P .= A_LoopField '"', 1)
				continue
			else if A
				LF := P A_LoopField, C.Push(InStr(LF, "\") ? UC(LF) : LF), P := ""
			else if V
				LF := P A_LoopField, map_set(C, K, InStr(LF, "\") ? UC(LF) : LF), K := V := P := ""
			else
				LF := P A_LoopField, K := InStr(LF, "\") ? UC(LF) : LF, P := ""
		}
		return J
		UC(S, e := 1) {
			static m := Map('"', '"', "a", "`a", "b", "`b", "t", "`t", "n", "`n", "v", "`v", "f", "`f", "r", "`r")
			local v := ""
			Loop Parse S, "\"
				if !((e := !e) && A_LoopField = "" ? v .= "\" : !e ? (v .= A_LoopField, 1) : 0)
					v .= (t := m.Get(SubStr(A_LoopField, 1, 1), 0)) ? t SubStr(A_LoopField, 2) :
						(t := RegExMatch(A_LoopField, "i)^(u[\da-f]{4}|x[\da-f]{2})\K")) ?
							Chr("0x" SubStr(A_LoopField, 2, t - 2)) SubStr(A_LoopField, t) : "\" A_LoopField,
							e := A_LoopField = "" ? e : !e
			return v
		}
	}

	/**
	 * Converts a AutoHotkey Array/Map/Object to a Object Notation JSON string.
	 * @param obj A AutoHotkey value, usually an object or array or map, to be converted.
	 * @param expandlevel The level of JSON string need to expand, by default expand all.
	 * @param space Adds indentation, white space, and line break characters to the return-value JSON text to make it easier to read.
	 */
	static stringify(obj, expandlevel := unset, space := "  ") {
		expandlevel := IsSet(expandlevel) ? Abs(expandlevel) : 10000000
		return Trim(CO(obj, expandlevel))
		CO(O, J := 0, R := 0, Q := 0) {
			static M1 := "{", M2 := "}", S1 := "[", S2 := "]", N := "`n", C := ",", S := "- ", E := "", K := ":"
			if (OT := Type(O)) = "Array" {
				D := !R ? S1 : ""
				for key, value in O {
					F := (VT := Type(value)) = "Array" ? "S" : InStr("Map,Object", VT) ? "M" : E
					Z := VT = "Array" && value.Length = 0 ? "[]" : ((VT = "Map" && value.count = 0) || (VT = "Object" && ObjOwnPropCount(value) = 0)) ? "{}" : ""
					D .= (J > R ? "`n" CL(R + 2) : "") (F ? (%F%1 (Z ? "" : CO(value, J, R + 1, F)) %F%2) : ES(value)) (OT = "Array" && O.Length = A_Index ? E : C)
				}
			} else {
				D := !R ? M1 : ""
				for key, value in (OT := Type(O)) = "Map" ? (Y := 1, O) : (Y := 0, O.OwnProps()) {
					F := (VT := Type(value)) = "Array" ? "S" : InStr("Map,Object", VT) ? "M" : E
					Z := VT = "Array" && value.Length = 0 ? "[]" : ((VT = "Map" && value.count = 0) || (VT = "Object" && ObjOwnPropCount(value) = 0)) ? "{}" : ""
					D .= (J > R ? "`n" CL(R + 2) : "") (Q = "S" && A_Index = 1 ? M1 : E) ES(key) K (F ? (%F%1 (Z ? "" : CO(value, J, R + 1, F)) %F%2) : ES(value)) (Q = "S" && A_Index = (Y ? O.count : ObjOwnPropCount(O)) ? M2 : E) (J != 0 || R ? (A_Index = (Y ? O.count : ObjOwnPropCount(O)) ? E : C) : E)
					if J = 0 && !R
						D .= (A_Index < (Y ? O.count : ObjOwnPropCount(O)) ? C : E)
				}
			}
			if J > R
				D .= "`n" CL(R + 1)
			if R = 0
				D := RegExReplace(D, "^\R+") (OT = "Array" ? S2 : M2)
			return D
		}
		ES(S) {
			switch Type(S) {
				case "Float":
					if (v := '', d := InStr(S, 'e'))
						v := SubStr(S, d), S := SubStr(S, 1, d - 1)
					if ((StrLen(S) > 17) && (d := RegExMatch(S, "(99999+|00000+)\d{0,3}$")))
						S := Round(S, Max(1, d - InStr(S, ".") - 1))
					return S v
				case "Integer":
					return S
				case "String":
					S := StrReplace(S, "\", "\\")
					S := StrReplace(S, "`t", "\t")
					S := StrReplace(S, "`r", "\r")
					S := StrReplace(S, "`n", "\n")
					S := StrReplace(S, "`b", "\b")
					S := StrReplace(S, "`f", "\f")
					S := StrReplace(S, "`v", "\v")
					S := StrReplace(S, '"', '\"')
					return '"' S '"'
				default:
					return S == this.true ? "true" : S == this.false ? "false" : "null"
			}
		}
		CL(i) {
			Loop (s := "", space ? i - 1 : 0)
				s .= space
			return s
		}
	}
}