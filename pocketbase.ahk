#Requires AutoHotkey v2.0

class Pocketbase {
    /************************************************************************
     * ; JSON library from https://github.com/thqby/ahk2_lib/blob/master/JSON.ahk
     * @description: JSON格式字符串序列化和反序列化, 修改自[HotKeyIt/Yaml](https://github.com/HotKeyIt/Yaml)
     * 增加了对true/false/null类型的支持, 保留了数值的类型
     * @author thqby, HotKeyIt
     * @date 2024/02/24
     * @version 1.0.7
     ***********************************************************************/
    class JSON {
        static null := ComValue(1, 0), true := ComValue(0xB, 1), false := ComValue(0xB, 0)

        /**
         * Converts a AutoHotkey Object Notation JSON string into an object.
         * @param text A valid JSON string.
         * @param keepbooltype convert true/false/null to JSON.true / JSON.false / JSON.null where it's true, otherwise 1 / 0 / ''
         * @param as_map object literals are converted to map, otherwise to object
         */
        static parse(text, keepbooltype := false, as_map := true) {
            keepbooltype ? (_true := this.true, _false := this.false, _null := this.null) : (_true := true, _false :=
                false, _null := "")
            as_map ? (map_set := (maptype := Map).Prototype.Set) : (map_set := (obj, key, val) => obj.%key% := val,
            maptype := Object)
            NQ := "", LF := "", LP := 0, P := "", R := ""
            D := [C := (A := InStr(text := LTrim(text, " `t`r`n"), "[") = 1) ? [] : maptype()], text := LTrim(SubStr(
                text, 2), " `t`r`n"), L := 1, N := 0, V := K := "", J := C, !(Q := InStr(text, '"') != 1) ? text :=
                LTrim(text, '"') : ""
            loop parse text, '"' {
                Q := NQ ? 1 : !Q
                NQ := Q && RegExMatch(A_LoopField, '(^|[^\\])(\\\\)*\\$')
                if !Q {
                    if (t := Trim(A_LoopField, " `t`r`n")) = "," || (t = ":" && V := 1)
                        continue
                    else if t && (InStr("{[]},:", SubStr(t, 1, 1)) || A && RegExMatch(t,
                        "m)^(null|false|true|-?\d+(\.\d*(e[-+]\d+)?)?)\s*[,}\]\r\n]")) {
                        loop parse t {
                            if N && N--
                                continue
                            if InStr("`n`r `t", A_LoopField)
                                continue
                            else if InStr("{[", A_LoopField) {
                                if !A && !V
                                    throw Error("Malformed JSON - missing key.", 0, t)
                                C := A_LoopField = "[" ? [] : maptype(), A ? D[L].Push(C) : map_set(D[L], K, C), D.Has(++
                                    L) ? D[L] := C : D.Push(C), V := "", A := Type(C) = "Array"
                                continue
                            } else if InStr("]}", A_LoopField) {
                                if !A && V
                                    throw Error("Malformed JSON - missing value.", 0, t)
                                else if L = 0
                                    throw Error("Malformed JSON - to many closing brackets.", 0, t)
                                else C := --L = 0 ? "" : D[L], A := Type(C) = "Array"
                            } else if !(InStr(" `t`r,", A_LoopField) || (A_LoopField = ":" && V := 1)) {
                                if RegExMatch(SubStr(t, A_Index),
                                "m)^(null|false|true|-?\d+(\.\d*(e[-+]\d+)?)?)\s*[,}\]\r\n]", &R) && (N := R.Len(0) - 2,
                                R := R.1, 1) {
                                    if A
                                        C.Push(R = "null" ? _null : R = "true" ? _true : R = "false" ? _false :
                                            IsNumber(R) ? R + 0 : R)
                                    else if V
                                        map_set(C, K, R = "null" ? _null : R = "true" ? _true : R = "false" ? _false :
                                            IsNumber(R) ? R + 0 : R), K := V := ""
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
                loop parse S, "\"
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
                        Z := VT = "Array" && value.Length = 0 ? "[]" : ((VT = "Map" && value.count = 0) || (VT =
                            "Object" && ObjOwnPropCount(value) = 0)) ? "{}" : ""
                        D .= (J > R ? "`n" CL(R + 2) : "") (F ? (%F%1 (Z ? "" : CO(value, J, R + 1, F)) %F%2) : ES(
                            value)) (OT = "Array" && O.Length = A_Index ? E : C)
                    }
                } else {
                    D := !R ? M1 : ""
                    for key, value in (OT := Type(O)) = "Map" ? (Y := 1, O) : (Y := 0, O.OwnProps()) {
                        F := (VT := Type(value)) = "Array" ? "S" : InStr("Map,Object", VT) ? "M" : E
                        Z := VT = "Array" && value.Length = 0 ? "[]" : ((VT = "Map" && value.count = 0) || (VT =
                            "Object" && ObjOwnPropCount(value) = 0)) ? "{}" : ""
                        D .= (J > R ? "`n" CL(R + 2) : "") (Q = "S" && A_Index = 1 ? M1 : E) ES(key) K (F ? (%F%1 (Z ?
                            "" : CO(value, J, R + 1, F)) %F%2) : ES(value)) (Q = "S" && A_Index = (Y ? O.count :
                                ObjOwnPropCount(O)) ? M2 : E) (J != 0 || R ? (A_Index = (Y ? O.count : ObjOwnPropCount(
                                    O)) ? E : C) : E)
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
                loop (s := "", space ? i - 1 : 0)
                    s .= space
                return s
            }
        }
    }
    class Utils {
        static JsonToObj(json) => Pocketbase.JSON.parse(json,,false)
        static ObjToJson(obj) => Pocketbase.JSON.stringify(obj)
        static MapToJson(map) => Pocketbase.JSON.stringify(map)
    }
    Class HttpResponse {
        responseBody := {}
        status := 0
        success := false
        statusText := ''
        headers := ''
        __New(responseBody, status, statusText, headers) {
            this.responseBody := responseBody
            this.status := status
            this.success := status >= 200 && status < 300
            this.statusText := statusText
            this.headers := headers
        }
        static FromResponse(response) {
            this.responseBody := Pocketbase.Utils.JsonToObj(response.responseText)
            this.status := response.status
            this.success := response.status >= 200 && response.status < 300
            this.statusText := response.statusText
            this.headers := response.GetAllResponseHeaders()
            return this
        }
    }
    class HttpRequest {
        __New(url, method) {
            this.url := url
            this.method := method
            this.body := ''
            this.http := ComObject("WinHttp.WinHttpRequest.5.1")
            this.http.Open(this.method, this.url)
        }
        SetBody(body) {
            if Type(body) == 'String' {
                this.body := body
                return this
            }
            if Type(body) == 'Object' {
                this.body := Pocketbase.Utils.ObjToJson(body)
                return this
            }
            if Type(body) == 'Map' {
                this.body := Pocketbase.Utils.MapToJson(body)
                return this
            }
            throw Error('Invalid body type')
        }
        SetHeaders(headers) {
            if Type(headers) == 'String' {
                this.http.SetRequestHeader(headers)
                return this
            }
            if Type(headers) == 'Object' {
                for prop, value in headers.OwnProps() {
                    this.http.SetRequestHeader(prop, value)
                }
                return this
            }
            if Type(headers) == 'Map' {
                for key, value in headers {
                    this.http.SetRequestHeader(key, value)
                }
                return this
            }
            throw Error('Invalid headers type')
        }
        Send(timeoutSeconds := 30) {
            this.http.Send(this.body)
            this.http.WaitForResponse(timeoutSeconds * 1000)
            response := Pocketbase.HttpResponse.FromResponse(this.http)
            return response
        }
        JustSend() {
            this.http.Send(this.body)
            return this.http
        }
    }
    Class AuthStore {
        token := ''
        userRecord := ''
        isValid {
            get {
                ; TODO
            }
        }
        __New(token, userRecord) {
            this.token := token
            this.userRecord := userRecord
        }
    }
    __New(host) {
        this.host := host
        this._collection := ''
        this._userAuthStore := Pocketbase.AuthStore('', '')
    }
    AuthWithPassword(identity, password, expand := '', fields := '') {
        query := expand ? '?expand=' expand : ''
        query .= fields ? '?fields=' fields : ''
        url := this.host '/api/collections/users/auth-with-password' query
        http := Pocketbase.HttpRequest(url, 'POST')
        http.SetBody({
            identity: identity,
            password: password
        })
        http.SetHeaders(Map(
            'Content-Type', 'application/json'
        ))
        response := http.Send()
        if response.success {
            this.userAuthStore := Pocketbase.AuthStore(response.responseBody.token, response.responseBody.record)
            return true
        }
        Throw Error(response.statusText ' ' response.status ' ' response.responseBody.message, -2)
    }
    RefreshToken(expand := '', fields := '') {
        if not this.userAuthStore.token {
            throw Error('Token not set. Authenticate first', -2)
        }
        query := expand ? '?expand=' expand : ''
        query .= fields ? '?fields=' fields : ''
        url := this.host '/api/collections/users/auth-refresh' query
        http := Pocketbase.HttpRequest(url, 'POST')
        http.SetHeaders(Map(
            'Authorization', this.userAuthStore.token,
            'Content-Type', 'application/json'
        ))
        response := http.Send()
        if response.success {
            this.userAuthStore := Pocketbase.AuthStore(response.responseBody.token, response.responseBody.record)
            return true
        }
        Throw Error(response.statusText ' ' response.status ' ' response.responseBody.message, -2)
    }
    Collection(collection) {
        this._collection := collection
        return this
    }
    List(page := '', perPage := '', sort := '', filter := '', expand := '', fields := '', skipTotal := '') {
        if not this._collection {
            Throw Error('Collection not set. Call Collection(collection) first', -2)
        }
        url := this.host '/api/collections/' this._collection '/records'
        query := page ? '?page=' page : ''
        query .= perPage ? '?perPage=' perPage : ''
        query .= sort ? '?sort=' sort : ''
        query .= filter ? '?filter=' filter : ''
        query .= expand ? '?expand=' expand : ''
        query .= fields ? '?fields=' fields : ''
        query .= skipTotal ? '?skipTotal=' skipTotal : ''
        url := url query
        http := Pocketbase.HttpRequest(url, 'GET')
        http.SetHeaders(Map(
            'Authorization', this.userAuthStore.token,
            'Content-Type', 'application/json'
        ))
        response := http.Send()
        if response.success {
            return response.responseBody
        }
        Throw Error(response.statusText ' ' response.status ' ' response.responseBody.message, -2)
    }
    Get(id, expand := '', fields := '') {
        if not this._collection {
            Throw Error('Collection not set. Call Collection(collection) first', -2)
        }
        url := this.host '/api/collections/' this._collection '/records/' id
        query := expand ? '?expand=' expand : ''
        query .= fields ? '?fields=' fields : ''
        url := url query
        http := Pocketbase.HttpRequest(url, 'GET')
        http.SetHeaders(Map(
            'Authorization', this.userAuthStore.token,
            'Content-Type', 'application/json'
        ))
        response := http.Send()
        if response.success {
            return response.responseBody
        }
        Throw Error(response.statusText ' ' response.status ' ' response.responseBody.message, -2)
    }
    Create(data, expand := '', fields := '') {
        if not this._collection {
            Throw Error('Collection not set. Call Collection(collection) first', -2)
        }
        if data.HasOwnProp('id') and data.id {
            Throw Error('Create requires data.id to be empty', -2)
        }
        data.id := ''
        url := this.host '/api/collections/' this._collection '/records'
        http := Pocketbase.HttpRequest(url, 'POST')
        http.SetHeaders(Map(
            'Authorization', this.userAuthStore.token,
            'Content-Type', 'application/json'
        ))
        http.SetBody(data)
        response := http.Send()
        if response.success {
            return data := response.responseBody
        }
        Throw Error(response.statusText ' ' response.status ' ' response.responseBody.message, -2)
    }
    Update(data, expand := '', fields := '') {
        if not this._collection {
            Throw Error('Collection not set. Call Collection(collection) first', -2)
        }
        if not data.HasOwnProp('id') or not data.id {
            Throw Error('Update requires data.id to be set', -2)
        }
        url := this.host '/api/collections/' this._collection '/records/' data.id
        query := expand ? '?expand=' expand : ''
        query .= fields ? '?fields=' fields : ''
        url := url query
        http := Pocketbase.HttpRequest(url, 'PATCH')
        http.SetHeaders(Map(
            'Authorization', this.userAuthStore.token,
            'Content-Type', 'application/json'
        ))
        http.SetBody(data)
        response := http.Send()
        if response.success {
            return data := response.responseBody
        }
        Throw Error(response.statusText ' ' response.status ' ' response.responseBody.message, -2)
    }
    Delete(id) {
        if not this._collection {
            Throw Error('Collection not set. Call Collection(collection) first', -2)
        }
        url := this.host '/api/collections/' this._collection '/records/' id
        http := Pocketbase.HttpRequest(url, 'DELETE')
        http.SetHeaders(Map(
            'Authorization', this.userAuthStore.token,
            'Content-Type', 'application/json'
        ))
        response := http.Send()
        if response.success {
            return true
        }
        Throw Error(response.statusText ' ' response.status ' ' response.responseBody.message, -2)
    }
}