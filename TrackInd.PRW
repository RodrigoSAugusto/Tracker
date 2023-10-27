#include "totvs.ch"
  
/*{Protheus.doc} u_TrackIndex()
    Funcao utilizando TWebEngine/TWebChannel para rastrear pedidos
    @author Rodrigo Augusto
    @since 27/07/2022
    @see: http://tdn.totvs.com/display/tec/twebengine
          http://tdn.totvs.com/display/tec/twebchannel
    @observation:
          Compativel com SmartClient Desktop(Qt);
*/


User function TrackInd()

    local oWebEngine
    local aSize             := MsAdvSize()
    local oModal
     

    private oWebChannel, oTrackIndex

    oModal := MSDialog():New(aSize[7],0,aSize[6],aSize[5], "Página Local",,,,,,,,,.T./*lPixel*/)
        // WebSocket (comunicacao AdvPL x JavaScript)
        oWebChannel := TWebChannel():New()
        oWebChannel:bJsToAdvpl := {|self,key,value| jsToAdvpl(self,key,value) } 
        oWebChannel:connect()
        
        // WebEngine (chromium embedded)
        oWebEngine := TWebEngine():New(oModal,0,0,100,100,/*cUrl*/,oWebChannel:nPort)
        oWebEngine:Align := CONTROL_ALIGN_ALLCLIENT
        
        // WebComponent de teste
        oTrackIndex := TrackIndex():Constructor()
        oWebEngine:navigate(;
            iif(oTrackIndex:GetOS()=="UNIX", "file://", "")+;
            oTrackIndex:mainHTML)
        
        // bLoadFinished sera disparado ao fim da carga da pagina
        // instanciando o bloco de codigo do componente, e tambem um customizado
        oWebEngine:bLoadFinished := {|webengine, url| oTrackIndex:OnInit(webengine, url)}


    oModal:Activate()

return


// Funcao customizada que sera disparada apos o termino da carga da pagina
static function myLoadFinish(oWebEngine, url)
    conout("-> myLoadFinish(): Termino da carga da pagina")
    conout("-> Class: " + GetClassName(oWebEngine))
    conout("-> URL: " + url)
    conout("-> TempDir: " + oTrackIndex::tmp)
   conout("-> Websocket port: " + cValToChar(oWebChannel:nPort))

    // Executa um runJavaScript
    oWebEngine:runJavaScript("alert('RunJavaScript: Termino da carga da pagina');")
return


// Blocos de codigo recebidos via JavaScript
static function jsToAdvpl(self,key,value)
	conout("",;
		"jsToAdvpl->key: " + key,;
           	"jsToAdvpl->value: " + value)

    // ---------------------------------------------------------------
    // Insira aqui o tratamento para as mensagens vindas do JavaScript
    // ---------------------------------------------------------------
    Do Case
        case key  == "<TrackOrdem>" // [Rastreia Ordem]
            
            u_TrackOrc()

        case key  == "<TrackPed>" // [Rastreia Pedido]

            u_TrackPed()

    EndCase
Return


// Classe WebComponent de teste
class TrackIndex
    data mainHTML
    data mainData
    data tmp

    Method Constructor() CONSTRUCTOR
    Method OnInit()     // Instanciado pelo bLoadFinished 
    Method Template()   // HTML inicial
    Method Script()     // JS inicial
    Method Style()      // Style inicial

    Method Get()
    Method Set()

    Method SaveFile(cContent)
    Method GetOS()
endClass


// Construtor
Method Constructor() class TrackIndex
    local cMainHTML
    ::tmp := GetTempPath()
    ::mainHTML := ::tmp + lower(getClassName(self)) + ".html"
    ::mainData := {} // Array com as variaveis globais (State)
 
    // ----------------------------------------------------
    // Importante: Compile o twebchannel.js em seu ambiente
    // ----------------------------------------------------
    // Baixa do RPO o arquivo twebchannel.js e salva no TEMP
    // Este arquivo eh responsavel pela comunicacao AdvPL x JS
    h := fCreate(iif(::GetOS()=="UNIX", "l:", "") + ::tmp + "twebchannel.js")
    fWrite(h, GetApoRes("twebchannel.js"))
    fClose(h)

    // HTML principal
    cMainHTML := ::Script() + chr(10) +;
                 ::Style() + chr(10) +;
                 ::Template()

    // Verifica se o HTML principal foi criado
    if !::SaveFile(cMainHTML)
        msgAlert("Arquivo HTML principal nao pode ser criado")
    endif
return

// Instanciado apos a carga da pagina HTML
Method OnInit(webengine, url) class TrackIndex
    // Desabilita pintura evitando refreshs desnecessarios
    webengine:SetUpdatesEnable(.F.)

    // -------------------------------------------------------------------
    // Importante: Acoes que dependam da carga devem ser instanciadas aqui
    // -------------------------------------------------------------------

    // Processa mensagens pendentes e reabilita pintura
    ProcessMessages()
    sleep(300)
    webengine:SetUpdatesEnable(.T.)
return

// Pagina HTML inicial
Method Template() class TrackIndex
    BeginContent var cHTML
        <script src="twebchannel.js"></script>
        <script>
            var track_pedido
            var track_ordem
            

            window.onload = function() {
                
                track_pedido = document.getElementById('track-Pedido');
                track_ordem = document.getElementById('track-Ordem');

                // Estabelece conexao entre o AdvPL e o JavaScript via WebSocket
                twebchannel.connect( () => { console.log('Websocket Connected!'); } );
                twebchannel.advplToJs = function(key, value) {

                    // ----------------------------------------------------------
                    // Insira aqui o tratamento para as mensagens vindas do AdvPL
                    // ----------------------------------------------------------
                    if (key === "<script>") {
                        let tag = document.createElement('script');
                        tag.setAttribute("type", "text/javascript");
                        tag.innerText = value;
                        document.getElementsByTagName("head")[0].appendChild(tag);
                    }
                    else if(key === "<track-pedido>") {
                        track_pedido.innerHTML  = value
                        
                    }
                    //else if(key === "<track-ordem>") {
                       
                    //    track_ordem.innerHTML   = value
                   // }
                   
                }
            };
        </script>
        <body style='background-color: #d1e6cc;'>
            <div class='flex-contariner'>
                <nav class="navbar navbar-dark justify-content-center" style='background-color: #217b4b;'>
                    <div>
                        <a class="navbar-brand">Rastreador</a>
                        <div class='divLine'>
                      
                    </div> 
                    </div>
                </nav>
            </div>
            <div class="container">
                <ul class="list-group">
                    <button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<TrackOrdem>`, `TrackOrc()`)'>RASTREADOR DE ATENDIMENTO/ORÇAMENTOS</button>
                    <button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<TrackPed>`, `TrackPed()`)'>RASTREADOR DE PEDIDOS/OP</button>
                </ul>
            </div>
        <body>
    EndContent
return cHTML

// Scripts
Method Script() class TrackIndex
    BeginContent var cScript

        
        <script>
            // [*Submit]
            onClickSubmit = (e, form) => {
                e.preventDefault()
                
                // Varre itens preenchidos
                let elements = form.elements
                let retToAdvpl = ""
                for(let i = 0 ; i < elements.length ; i++){
                    let item = elements.item(i)
                    if (form.elements[i].type != "submit"){
                        retToAdvpl += item.value

                        //Se o proximo elemento for um submit nao insere o separador
                        if (form.elements[i+1].type != "submit"){
                            retToAdvpl += ","
                        }
                    }
                }

                // Retorna informacoes do Form para o AdvPL
                
                twebchannel.jsToAdvpl("<submit>", retToAdvpl)
                form.reset()
                document.getElementById("pedido").focus()
                return false
            }
        </script>
    EndContent
return cScript   

// Estilos
Method Style() class TrackIndex
    BeginContent var cStyle


        <!--// Links Bootstrap que adicionam css e js com resposividade.-->
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-MrcW6ZMFYlzcLA8Nl+NtUVF0sA7MsXsP1UyJoMp4YLEuNSfAP+JcXn/tWtIaxVXM" crossorigin="anonymous"></script>
        
        <style>
           <!-- Adicionar estilos personalizados aqui-->
            body {
                background: #488d36;
            }
            .flex-container {
                display: flex;
                background-color: #488d36;
                
            }
            h3 {
                text-align: center;
            }
            /* Dropdown Button */
            .dropbtn {
            background-color: #217b4b;
            color: white;
            padding: 16px;
            font-size: 16px;
            border: none;
            margin: 16px;
            }

            /* The container <div> - needed to position the dropdown content */
            .dropdown {
            position: relative;
            display: inline-block;
            }

            /* Dropdown Content (Hidden by Default) */
            .dropdown-content {
            display: none;
            position: absolute;
            background-color: #f1f1f1;
            min-width: 160px;
            box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2);
            z-index: 1;
            }

            /* Links inside the dropdown */
            .dropdown-content a {
            color: black;
            padding: 12px 16px;
            text-decoration: none;
            display: block;
            }

            /* Change color of dropdown links on hover */
            .dropdown-content a:hover {background-color: #ddd;}

            /* Show the dropdown menu on hover */
            .dropdown:hover .dropdown-content {display: block;}

            /* Change the background color of the dropdown button when the dropdown content is shown */
            .dropdown:hover .dropbtn {background-color: #3e8e41;}

        </style>

    EndContent
return cStyle

// Getter [*Getter_and_Setter]
Method Get(cVarname) class TrackIndex
    // Recupera valor do array global (State)
    local nPosBase := AScan( ::mainData, {|x| x[1] == cVarname} )
    if nPosBase > 0
        return ::mainData[nPosBase, 2]
    endif
return ""

// Setter [*Getter_and_Setter]
Method Set(cVarname, xValue, bUpdate) class TrackIndex
    // Define/Atualiza valor do array global (State)
    local nPosBase := AScan( ::mainData, {|x| x[1] == cVarname} )
    if nPosBase > 0
        if valType(xValue) == "A"
            ::mainData[nPosBase, 2] := aClone(xValue)
        else
            ::mainData[nPosBase, 2] := xValue
        endif
    else
        Aadd(::mainData, {cVarname, xValue})
    endif
    // Zera variavel global
    xValue := {}
    
    // Dispara bloco de codigo customizado
    // apos atualizacao do valor
    if valtype(bUpdate) == "B"
        eval(bUpdate)
    endif
return

// Salva arquivo em disco
Method SaveFile(cContent) class TrackIndex
    local nHdl := fCreate(iif(::GetOS()=="UNIX", "l:", "") + ::mainHTML)
    if nHdl > -1
        fWrite(nHdl, cContent)
        fClose(nHdl)
    else
        return .F.
    endif
return .T.

// Retorna Sistema Operacional em uso
Method GetOS() class TrackIndex
    local stringOS := Upper(GetRmtInfo()[2])

    if GetRemoteType() == 0 .or. GetRemoteType() == 1
        return "WINDOWS"
    elseif GetRemoteType() == 2 
        return "UNIX" // Linux ou MacOS		
    elseif GetRemoteType() == 5 
        return "HTML" // Smartclient HTML		
    elseif ("ANDROID" $ stringOS)
        return "ANDROID" 
    elseif ("IPHONEOS" $ stringOS)
        return "IPHONEOS"
    endif    
return ""
