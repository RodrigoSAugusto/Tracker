#include "totvs.ch"
  
/*{Protheus.doc} u_TrackOrc()
    Funcao utilizando TWebEngine/TWebChannel para rastrear Orçamentos
    @author Rodrigo Augusto
    @since 21/06/2022
    @see: http://tdn.totvs.com/display/tec/twebengine
          http://tdn.totvs.com/display/tec/twebchannel
    @observation:
          Compativel com SmartClient Desktop(Qt);
*/


User function TrackOrc()

    local oWebEngine
    local aSize                 := MsAdvSize()
    local oModal
    private aOrcamentoLocal     := {}
    private aOrdemLocal         := {}
    private aComercialLocal     := {}
    private aVoltar             := {}
    private cRetornoOrc
    

    private oWebChannel, oTrackOrc

    oModal := MSDialog():New(aSize[7],0,aSize[6],aSize[5], "Página Local",,,,,,,,,.T./*lPixel*/)
        // WebSocket (comunicacao AdvPL x JavaScript)
        oWebChannel := TWebChannel():New()
        oWebChannel:bJsToAdvpl := {|self,key,value| jsToAdvpl(self,key,value) } 
        oWebChannel:connect()
        
        // WebEngine (chromium embedded)
        oWebEngine := TWebEngine():New(oModal,0,0,100,100,/*cUrl*/,oWebChannel:nPort)
        oWebEngine:Align := CONTROL_ALIGN_ALLCLIENT
        
        // WebComponent de teste
        oTrackOrc := TrackOrc():Constructor()
        oWebEngine:navigate(;
            iif(oTrackOrc:GetOS()=="UNIX", "file://", "")+;
            oTrackOrc:mainHTML)
        
        // bLoadFinished sera disparado ao fim da carga da pagina
        // instanciando o bloco de codigo do componente, e tambem um customizado
        oWebEngine:bLoadFinished := {|webengine, url| oTrackOrc:OnInit(webengine, url)}


    oModal:Activate()

return

// Funcao customizada que sera disparada apos o termino da carga da pagina
static function myLoadFinish(oWebEngine, url)
    conout("-> myLoadFinish(): Termino da carga da pagina")
    conout("-> Class: " + GetClassName(oWebEngine))
    conout("-> URL: " + url)
    conout("-> TempDir: " + oTrackOrc::tmp)
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
        case key  == "<submit>" .or. key  == "<voltar>"// Função chamada ao Digitar o NUmero do Orçamento para pesquisa.

            if Len(value) = 6
                aadd( aOrcamentoLocal, StrTokArr(value, ",") )
                oTrackOrc:set("aOrcamento", aOrcamentoLocal, {|| fSQLOrcamento()} )
            Else
                MsgStop("O Numero de Orçamentos precisa ter 6 digitos!", "Atencao")
            EndIf

            
        case key  == "<ordem>" // Função chamada ao selecionar ordem na lista.

            aadd( aOrdemLocal, StrTokArr(value, ",") )
            oTrackOrc:set("aOrdem", aOrdemLocal, {|| fSQLOrdem()} )


        case key  == "<comercial>" // Função chamada ao clicar nos botões que alteram os status do Orçamento/Pedido.

            aadd( aComercialLocal, StrTokArr(value, ",") )
            oTrackOrc:set("aComercial", aComercialLocal, {|| fStComercial()} )
        

    EndCase
Return

//----------------------------------------------------------------
//Pesquisa no banco e guarda dados em variaveis.
// ---------------------------------------------------------------
static function fSQLOrcamento()
    local cOrcameDados      := ""
    local aOrcamento        := oTrackOrc:get("aOrcamento")
    local y                 := 0
    local x                 := 0
    local cNada             := ""
    private cOrcamento      := AllTrim(aOrcamento[1][1])
    public cPedidosDados    := ""
    private cDataEmiPed     := ""
    private cDataEntPed     := ""
    private cCodClient      := ""
    private cRazaoSocial    := ""
    private cNomeReduzi     := ""
    private cCNPJ           := ""
    private aArrayOrdem     := {}
    private cPedido         := ""
    private cNotaFis        := ""
    private cCodOperador    := ""
    private cDataEmiOrc     := ""
    private aLogUser        := ""
    private cLoja           := ""
    private cHoraEmiOrc     := ""
    private aMultLog        := {}
    private aMultLogUser    := {}
    private cDtDif          := "123"
    private cRetornoOrc     := cOrcamento
    private LibProjeto      := GetMv("MV_LIBPROJ")
    private LibCredito      := GetMv("MV_LIBCRED")
    private LibEngenharia   := GetMv("MV_LIBENGE")
    
   
    //Consulta SUA e pega Codigo do cliente e Data da emissão do Orcamento.
        BEGINSQL ALIAS "SQL_SUA"
        SELECT  UA_NUMSC5,
                UA_DOC,
                UA_CLIENTE,
                UA_LOJA,
                UA_OPERADO,
                CONVERT(VARCHAR(10),CONVERT(DATE,UA_EMISSAO,103),103) AS UA_EMISSAO,
                UA_FIM
                    FROM SUA010
                    WHERE UA_FILIAL = %xFilial:SUA%
                        AND UA_NUM = %EXP:cOrcamento%
                        //AND SUA.%notDel%
        ENDSQL

        //Se houve dados
        If ! SQL_SUA->(EoF())

            SQL_SUA->( dbGoTop() )

                cCodClient      := SQL_SUA->UA_CLIENTE
                cPedido         := SQL_SUA->UA_NUMSC5
                cLoja           := SQL_SUA->UA_LOJA
                cNotaFis        := SQL_SUA->UA_DOC
                cCodOperador    := SQL_SUA->UA_OPERADO
                cDataEmiOrc     := SQL_SUA->UA_EMISSAO
                cHoraEmiOrc     := SQL_SUA->UA_FIM

            SQL_SUA->( dbCloseArea() )


            //Consulta SA1 e pega Razão social, Nome Reduz e CNPJ.
            BEGINSQL ALIAS "SQL_SA1"
                SELECT  A1_NOME,
                        A1_NREDUZ,
                        A1_CGC
                    FROM %table:SA1% SA1
                    WHERE  A1_COD = %EXP:cCodClient%
                        AND A1_FILIAL = %xFilial:SA1%
                        AND A1_LOJA = %EXP:cLoja%
                        AND SA1.%notDel%
            ENDSQL

            //Se houve dados
            If ! SQL_SA1->(EoF())

                SQL_SA1->( dbGoTop() )

                    cRazaoSocial    := SQL_SA1->A1_NOME
                    cNomeReduzi     := SQL_SA1->A1_NREDUZ
                    cCNPJ           := SQL_SA1->A1_CGC

                SQL_SA1->( dbCloseArea() )

            else 
                //Caso não haja dados na SA1 consulta SUS e pega Razão social, Nome Reduz e CNPJ.
                BEGINSQL ALIAS "SQL_SUS"
                SELECT  US_NOME,
                        US_NREDUZ,
                        US_CGC
                    FROM %table:SUS% SUS
                    WHERE  US_COD = %EXP:cCodClient%
                        AND US_FILIAL = %xFilial:SA1%
                        AND US_LOJA = %EXP:cLoja%
                        AND SUS.%notDel%
                ENDSQL

                //Se houve dados
                If ! SQL_SUS->(EoF())

                    SQL_SUS->( dbGoTop() )

                        cRazaoSocial    := SQL_SUS->US_NOME
                        cNomeReduzi     := SQL_SUS->US_NREDUZ
                        cCNPJ           := SQL_SUS->US_CGC

                    SQL_SUS->( dbCloseArea() )
                    SQL_SA1->( dbCloseArea() )
                else

                    MsgStop("Nao foram encontrados dados do Prospect/Cliente!", "Atencao")
                    SQL_SA1->( dbCloseArea() )
                    SQL_SUS->( dbCloseArea() )

                EndIf
            EndIf
        

        //Consulta ZRP010 e pega os Logs de alreração de usuários do Orçamento.
        
            BEGINSQL ALIAS "SQL_ZRP"
                SELECT  ZRP_USER,
                        ZRP_USERID,
                        CONVERT(VARCHAR,CONVERT(DATE,ZRP_DATA), 103) AS LOGDATE,
                        CONVERT(VARCHAR,CONVERT(TIME,ZRP_DATA), 108) AS LOGTIME,
                        ZRP_STATUS,
                        CONVERT(VARCHAR,R_E_C_N_O_) AS RECNO
                    FROM    %table:ZRP010% ZRP010 (NOLOCK)
                            WHERE   ZRP_NUMERO = %EXP:cOrcamento%
                                AND ZRP_FILIAL = %xFilial:ZRP%
                                //AND ZRP.%notDel%
                ORDER BY CONVERT(DATETIME,ZRP_DATA)
            ENDSQL

            

            //Se houve dados
            If ! SQL_ZRP->(EoF())
                SQL_ZRP->( dbGoTop() )

                    While ! SQL_ZRP->(EoF())

                        aLogUser := SQL_ZRP->ZRP_USER + "," +;
                                    SQL_ZRP->ZRP_USERID + "," +;
                                    SQL_ZRP->LOGDATE + "," +;
                                    SQL_ZRP->LOGTIME + "," +;
                                    SQL_ZRP->ZRP_STATUS + "," +;
                                    SQL_ZRP->RECNO

                        aadd( aMultLogUser, StrTokArr(aLogUser, ",") )

                        SQL_ZRP->(DbSkip())

                    EndDo

                SQL_ZRP->( dbCloseArea() )
            Else

                MsgStop("Nao foram encontrados Dados de Log do Orçamento!", "Atencao")
                SQL_ZRP->( dbCloseArea() )

            EndIf    

        Else
            MsgStop("Nao foram encontrados Dados do Orçamento!", "Atencao")
            SQL_SUA->( dbCloseArea() )
            u_trackorc()
            oWebChannel:advplToJS("<reload-page>", cNada)
            Break
        EndIf

        
     
    // Constroi HTML que será inserido na pagina com os dados.
        // Dados da SC5 e SC6
        cOrcameDados +=;
        "<div class='container'>"                                                                                   +;
            "<div class='fluid-container'>"                                                                         +;
                        "<div class='input col-2'><label for='pedido'>          </label>"                           +;
                            "<button id='btnvoltar' class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<voltar>`,"  +;
                            "`"+ cOrcamento +"`)'>VOLTAR</button>"                                                  +;
                        "</div>"                                                                                    +;
                    "<h3>Dados do Orcamento</h3>"                                                                   +;
                "</div>"                                                                                            +;
            "<div class='row justify-content-center'>"                                                              +;
                "<div class='col-2'>"                                                                               +;
                    "<label for='Orcamento'>N° Orcamento</label> "                                                  +;
                    "<input type='text' class='form-control' id='Orcamento' value='"+ cOrcamento +"' readonly>"     +;
                "</div>"                                                                                            +;
                "<div class='col-3'>"                                                                               +;
                    "<label for='Orcamento'>Data de Emissão</label> "                                               +;
                    "<input type='text' class='form-control' id='Orcamento' value='"+ cDataEmiOrc +"' readonly>"    +;
                "</div>"                                                                                            +;
                "<div class='col-3'>"                                                                               +;
                    "<label for='Orcamento'>N° Pedido</label> "                                                     +;
                    "<input type='text' class='form-control' id='Orcamento' value='"+ cPedido +"' readonly>"        +;
                "</div>"                                                                                            +;
            "</div>"                                                                                                +;
        "</div>"

    // Dados da SA1
        cOrcameDados +=;
        "<div class='container'>"                                                                                   +;
            "<div class='row justify-content-center'>"                                                              +;
                "<div class='col-2'>"                                                                               +;
                    "<label for='Orcamento'>Cliente</label> "                                                       +;
                    "<input type='text' class='form-control' id='Orcamento' value='"+ cCodClient +"' readonly>"     +;
                "</div>"                                                                                            +;
                "<div class='col-2'>"                                                                               +;
                    "<label for='Orcamento'>Loja</label> "                                                          +;
                    "<input type='text' class='form-control' id='Orcamento' value='"+ cLoja +"' readonly>"          +;
                "</div>"                                                                                            +;
                "<div class='col-3'>"                                                                               +;
                    "<label for='Orcamento'>Razão Social</label> "                                                  +;
                    "<input type='text' class='form-control' id='Orcamento' value='"+ cRazaoSocial +"' readonly>"   +;
                "</div>"                                                                                            +;
                "<div class='col-3'>"                                                                               +;
                    "<label for='Orcamento'>Nome Reduzido</label> "                                                 +;
                    "<input type='text' class='form-control' id='Orcamento' value='"+ cNomeReduzi +"' readonly>"    +;
                "</div>"                                                                                            +;
                "<div class='col-3'>"                                                                               +;
                    "<label for='Orcamento'>CNPJ</label> "                                                          +;
                    "<input type='text' class='form-control' id='Orcamento' value='"+ cCNPJ +"' readonly>"          +;
                "</div>"                                                                                            +;
            "</div>"                                                                                                +;
        "</div>"                                                                                                    +;
        "<div class='container'>"                                                                                           
    //Alimenta a tabela com os Logs e calcula o tempo de espera de cada Operador.
            
                    cOrcameDados +=;
                    "<br>"+;
                    "<table class='table table-bordered table-striped table-dark'>"+;
                    "<tr><td>Usuário</td>"+;
                    "<td>Cód. Usuário</td>"+;
                    "<td>Data</td>"+;
                    "<td>Hora</td>"+;
                    "<td>Tempo Decorrido</td>"+;
                    "</tr>"   //Fechamos o cabeçalho
                    For y:=1  To Len(aMultLogUser)
                        fDateDif(aMultLogUser,  y)
                        cOrcameDados +=;
                            "<tr><td>"+ AllTrim(aMultLogUser[y][1]) +"</td>"+;
                                "<td>"+ AllTrim(aMultLogUser[y][2]) +"</td>"+;
                                "<td>"+ AllTrim(aMultLogUser[y][3]) +"</td>"+;
                                "<td>"+ AllTrim(aMultLogUser[y][4]) +"</td>"+;
                                "<td>" + CVALTOCHAR(cDtDif) + "</td>"+;
                            "</tr>"
                    Next y

                    If (aMultLogUser[y][2]) = "-"
                        cOrcameDados +=;
                            "<tr><td>"+ AllTrim(aMultLogUser[y][1]) +"</td>"+;
                                "<td>"+ AllTrim(aMultLogUser[y][2]) +"</td>"+;
                                "<td>"+ AllTrim(aMultLogUser[y][3]) +"</td>"+;
                                "<td>"+ AllTrim(aMultLogUser[y][4]) +"</td>"+;
                                "<td>" + CVALTOCHAR(cDtDif) + "</td>"+;
                            "</tr>"
                    EndIf

    cOrcameDados += "</div>"

    If !empty(cPedido)

        x := 0   

        //Consulta SC5 e pega Codigo do cliente e Data da emissão do pedido.
            BEGINSQL ALIAS "SQL_SC5"
            SELECT  C5_CLIENT,
                    CONVERT(VARCHAR(10),CONVERT(DATE,C5_EMISSAO,103),103) AS C5_EMISSAO
                FROM %table:SC5% SC5
                WHERE  C5_NUM = %EXP:cPedido%
                    AND C5_FILIAL = %xFilial:SC5%
                    AND SC5.%notDel%
            ENDSQL

            //Se houve dados
            If ! SQL_SC5->(EoF())

                SQL_SC5->( dbGoTop() )

                    cCodClient  := SQL_SC5->C5_CLIENT
                    cDataEmiPed := SQL_SC5->C5_EMISSAO

                SQL_SC5->( dbCloseArea() )

            Else

                MsgStop("Nao foram encontrados Dados do Pedido!", "Atencao")
                SQL_SC5->( dbCloseArea() )

            EndIf

        //Consulta SC6 e pega os dados de data de entrega prevista.
            BEGINSQL ALIAS "SQL_SC6"
                SELECT  CONVERT(VARCHAR(10),CONVERT(DATE,C6_ENTREG,103),103) AS C6_ENTREG

                    FROM %table:SC6% SC6
                    WHERE  C6_NUM = %EXP:cPedido%
                        AND C6_ITEM BETWEEN '01' and '99'
                        AND C6_FILIAL = %xFilial:SC6%
                        AND SC6.%notDel%
            ENDSQL

            //Se houve dados
            If ! SQL_SC6->(EoF())

                SQL_SC6->( dbGoTop() )

                    cDataEntPed     := SQL_SC6->C6_ENTREG

                SQL_SC6->( dbCloseArea() )

            Else

                MsgStop("Nao foram encontrados Dados da Data de Entrega!", "Atencao")
                SQL_SC6->( dbCloseArea() )

            EndIf


        //Consulta SC2 e pega Numero da OP, Data Emissão da OP, Data da Previsão de Entrega da OP e Data de Entrega real da OP.
            BEGINSQL ALIAS "SQL_SC2"
                SELECT  CONCAT(C2_NUM, C2_ITEM, C2_SEQUEN) AS C2_OP                
                    FROM %table:SC2% SC2
                    WHERE  C2_PEDIDO = %EXP:cPedido%
                        AND C2_FILIAL = %xFilial:SC2%
                        AND SC2.%notDel%
            ENDSQL

            If ! SQL_SC2->(EoF())

                SQL_SC2->( dbGoTop() )

                    While ! SQL_SC2->(EoF())

                        cConcatOrdem  :=  SQL_SC2->C2_OP 

                        aadd( aArrayOrdem, StrTokArr(cConcatOrdem, ",") )

                        SQL_SC2->(DbSkip())

                    EndDo

                SQL_SC2->( dbCloseArea() )
                
            Else

                MsgStop("Nao foram encontrados Dados das Ordens de Produção!", "Atencao")
                SQL_SC2->( dbCloseArea() )

            EndIf


        // Constroi HTML que será inserido na pagina com os dados.
            // Verifica o Status do Orçamento/Pedido e monta o botão de alteração do status.

                If (aMultLogUser[y][5]) = "PED" .or. (aMultLogUser[y][5]) = "PEP"       // PED = Pedido PEP = Pedido que passará pelo Projeto
                    cComercial := "Vendedor."
                elseif (aMultLogUser[y][5]) = "COM" .or. (aMultLogUser[y][5]) = "COP"   //
                    cComercial := "Lib. Comercial."
                elseif (aMultLogUser[y][5]) = "CRE" .or. (aMultLogUser[y][5]) = "CRP"
                    cComercial := "Lib. Credito."
                elseif (aMultLogUser[y][5]) = "PRJ"
                    cComercial := "Lib. Projeto."
                elseif (aMultLogUser[y][5]) = "ENG" .or. (aMultLogUser[y][5]) = "ENP"
                    cComercial := "Lib. Engenharia."  
                elseif (aMultLogUser[y][5]) = "CAN"
                    cComercial := "Pedido/Atendimento Cancelado."
                elseif (aMultLogUser[y][5]) = "PRD" .or. (aMultLogUser[y][5]) = "PRP"
                    cComercial := "Liberado para Produção."
                elseif (aMultLogUser[y][5]) = "NF."
                    cComercial := "Pedido Faturado"
                else
                    cComercial := "Atendimento"
                EndIf
                
                cRecnoStatus    := AllTrim(aMultLogUser[y][6]) + "," + AllTrim(aMultLogUser[y][5])
                cRecno          := AllTrim(aMultLogUser[y][6])

                cPedidosDados +=;
                "<div class='container'>"                                                                                           +;
                    "<div class='fluid-container'>"                                                                                 +;
                        "<h3>Dados do Pedido</h3>"                                                                                  +;
                    "</div>"                                                                                                        +;
                    "<div class='row justify-content-center'>"
                
                cPedidosDados +=;
                        "<div class='col-2'>"                                                                                   +;
                            "<label for='pedido'>N° Pedido</label> "                                                            +;
                            "<input type='text' class='form-control' id='pedido' value='"+ cPedido +"' readonly>"               +;
                        "</div>"                                                                                                +;
                        "<div class='col-3'>"                                                                                   +;
                            "<label for='pedido'>Data de Emissão</label> "                                                      +;
                            "<input type='text' class='form-control' id='pedido' value='"+ cDataEmiPed +"' readonly>"           +;
                        "</div>"                                                                                                +;
                        "<div class='col-3'>"                                                                                   +;
                            "<label for='pedido'>Data de Entrega</label> "                                                      +;
                            "<input type='text' class='form-control' id='pedido' value='"+ cDataEntPed +"' readonly>"           +;
                        "</div>"  

                cPedidosDados +=;
                    "</div>"                                                                                                    +;
                "</div>"

                cPedidosDados +=;
                "<div class='container'>"                                                                                           +;
                    "<div class='row justify-content-center'>"

                If (aMultLogUser[y][5]) = "PRJ" // Verifica se o status é projeto ou não, e apresenta o botão correto.
                    cPedidosDados +=;
                        "<div class='input col-2'><label for='pedido'>Retirar do Projeto?</label>"                                  +;
                            "<button id='btnvoltar' class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,"+;
                            "`"+ cRecno +",SAIPRJ`)'>Retirar</button>"                                                              +;
                        "</div>"
                Else
                    cPedidosDados +=;
                        "<div class='input col-2'><label for='pedido'>Enviar para Projeto?</label>"                                 +;
                            "<button id='btnvoltar' class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,"+;
                            "`"+ cRecno +",VAIPRJ`)'>Enviar</button>"                                                               +;
                        "</div>"

                EndIf

                If  __CUSERID $ LibProjeto .and. (aMultLogUser[y][5]) = "PRJ" // Verifica se o usuário esta na lista de usuários do projeto

                    cPedidosDados +=;
                    "<div class='input col-2'><label for='pedido'>Estágio de liberação</label>"                     +;
                        "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,"   +; //Botão para Voltar do projeto para a Comercial.
                        "`"+ cRecnoStatus +"`)'>Liberar para Engenharia</button>"                                        +;
                    "</div>"

                ElseIf __CUSERID $ LibCredito .and. (aMultLogUser[y][5]) $ "CRE-CRP" // Verifica se o usuário esta na lista de usuários da liberação de crédito.

                    cPedidosDados +=;
                    "<div class='input col-2'><label for='pedido'>Estágio de liberação</label>"                     +;
                        "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,"   +; //Botão para Voltar do Lib crédito para a Comercial.
                        "`"+ cRecnoStatus +"`)'>" + cComercial + "</button>"                                        +;
                    "</div>"

                ElseIf __CUSERID $ LibEngenharia .and. (aMultLogUser[y][5]) $ "ENG-ENP-PRD-PRP" // Verifica se o usuário esta na lista de usuários da liberação de Engenharia.

                    cPedidosDados +=;
                    "<div class='input col-2'><label for='pedido'>Estágio de liberação</label>"                     +;
                        "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,"   +; //Botão para Voltar da lib Engenharia para a Comercial.
                        "`"+ cRecnoStatus +"`)'>" + cComercial + "</button>"                                        +;
                    "</div>"

                Else //Se não for Usuário de Credito, Projeto ou Engenharia verifica se o usuário é um vendedor atravez da tabela SZB.

                    cNewOperCod     := __CUSERID
                    cCodVendedor    := ""

                    BEGINSQL ALIAS "SQL_SU7"
                    SELECT 	U7_CODVEN,
                            U7_NREDUZ
                        FROM SU7010 
                            WHERE 	U7_CODUSU = %EXP:cNewOperCod%
                                AND U7_FILIAL = %EXP:cFILANT%

                    ENDSQL

                    //Se houve dados
                        If ! SQL_SU7->(EoF())

                            SQL_SU7->( dbGoTop() )

                                cCodVendedor    := SQL_SU7->U7_CODVEN

                            SQL_SU7->( dbCloseArea() )

			            EndIf
                        If Select("SQL_SU7") > 0
                            dbSelectArea("SQL_SU7")
                            dbCloseArea()
                        EndIf
                    //Verifica se a variável esta vazia e adicona o HTML condizente com o usuário.
                    If !Empty(cCodVendedor)

                        cPedidosDados +=;
                        "<div class='input col-2'><label for='pedido'>Estágio de Liberação</label>"                     +;
                            "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,"   +; //Botão para Voltar do Lib crédito para a Comercial.
                            "`"+ cRecnoStatus +"`)'>" + cComercial + "</button>"                                        +;
                        "</div>"

                    Else

                        cPedidosDados +=;
                        "<div class='input col-2'><label for='pedido'>Estágio de liberação</label>"                     +;
                            "<button class='btn btn-outline-secondary'>" + cComercial + "</button>"                     +;
                        "</div>"

                    EndIf


                EndIf                                                                                     

                If  __CUSERID $ LibProjeto .and. (aMultLogUser[y][5]) = "PRJ"

                    cPedidosDados +=;
                        "<div class='input col-2'><label for='pedido'>Enviar Para Engenharia?</label>"                                          +;
                            "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,`"+ cRecno +",PRJLIB`)"    +;
                            "'>Enviar</button>"                                             +;
                        "</div>"

                ElseIf __CUSERID $ LibEngenharia .and. (aMultLogUser[y][5]) $ "ENG-ENP-PRD-PRP" // Verifica se o usuário esta na lista de usuários da liberação de Engenharia.

                    If (aMultLogUser[y][5]) = "ENG"
                        cPedidosDados +=;
                            "<div class='input col-2'><label for='pedido'>Liberar Para Produção</label>"                    +;
                                "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,"   +;  //Botão para Liberação da engenharia para produção.
                                "`"+ cRecno +",ENGLIB`)'>LIBERAR</button>"                                                  +;
                            "</div>"

                    Else
                        cPedidosDados +=;
                            "<div class='input col-2'><label for='pedido'>Liberar Para Produção</label>"                    +;
                                "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<comercial>`,"   +;  //Botão para Liberação da engenharia para produção.
                                "`"+ cRecno +",ENPLIB`)'>LIBERAR</button>"                                                  +;
                            "</div>"
                    EndIf

                EndIf

            cPedidosDados +=;
                "</div>"                                                                                                +;
            "</div>"

        // Dados da SA1
            cPedidosDados +=;
            "<div>"                                                                                                     +;
                "<div class='container'>"                                                                               +;
                    "<div class='dropdown'>"                                                                            +;
                        "<button class='dropbtn'>Ordens de Produção</button>"                                           +;
                        "<div class='dropdown-content'>"                                                                +;
                            "<div class='input-group mb-3'>"
        //Alimenta o menu dropdown com os númenos das ops.
                        For x:=1 To Len(aArrayOrdem)
                            cOP := aArrayOrdem[x][1]

                            cPedidosDados +=;
                                "<div class='input-group mb-4'>"                                                                                        +;
                                    "<input type='text' class='form-control' aria-describedby='basic-addon2' "                                          +;
                                    " id='ordem' value='" + cOP + "' readonly>"                                                                         +;
                                    "<div class='input-group-append'>"                                                                                  +;
                                        "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<ordem>`,`" + cOP + "`)'>IR</button>"+;
                                    "</div>"                                                                                                            +;
                                "</div>"
                        Next x

                    cPedidosDados +=;
                            "</div>"                                                                                                                    +;
                        "</div>"                                                                                                                        +;
                    "</div>"                                                                                                                            +;
                "</div>"                                                                                                                                +;
            "</div>"


        cOrcameDados += cPedidosDados

    EndIf

    oWebChannel:advplToJS("<track-orcamento>", cOrcameDados)

return

static function fDateDif(aMultLogUser, y)
    local z     := 0
    local cTime := " , , ," + TIME() +", ," + AllTrim(aMultLogUser[y][6]) + ","

    a := y + 1
    cDate1      := ctod(aMultLogUser[y][3])
    cHoraI      := "00:00:00"
    cDayHours   := "00:00:00"
    cDayAdd     := "24:00:00"

    IF 1=1
        IIf(y <> len(aMultLogUser), cDate2 := ctod(aMultLogUser[a][3]), cDate2 := DATE())
        IIf(y <> len(aMultLogUser), , aadd( aMultLogUser, StrTokArr(cTime,",")))       // Adiciona maia um item ao array com a data e hora para fazer o calculo final/atual de tempo decorrido; 
         
    ENDIF


    DO CASE

        CASE y = 1

            cDtDif := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

        RETURN cDtDif += " Inicio do Rastreamento."

        // Bloco de calculo de tempo Total, após a emissão da NF. 
        CASE (aMultLogUser[y][5]) = "NF."

            DO CASE

                CASE DateDiffDay(cDate1, cDate2) < 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Emissão da NF."

                CASE DateDiffDay(cDate1, cDate2) = 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Emissão da NF."

                CASE DateDiffDay(cDate1, cDate2) > 1
                    cDayCount  := DateDiffDay(cDate1, cDate2)
                    For z:=1  To cDayCount

                        cDayHours := SomaHoras(cDayHours ,cDayAdd)

                    Next z

                    cHourCount := CVALTOCHAR(ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4])))
                    cHourCount := CVALTOCHAR(cDayCount) + " dias e " + cHourCount + " horas"

                    cDtDif := cHourCount

                RETURN cDtDif += ". Emissão da NF."

            ENDCASE

        // Bloco de calculo de tempo caso o Pedido esteja parado na Produção.
        CASE (aMultLogUser[y][5]) = "PRD" .or. (aMultLogUser[y][5]) = "PRP"

            If(aMultLogUser[a][1]) = " "
                (aMultLogUser[a][1]) := "PRODUÇÃO"
                (aMultLogUser[a][2]) := "-"
                (aMultLogUser[a][4]) := TIME()
                (aMultLogUser[a][5]) := "PRD"
            EndIf

            DO CASE

                CASE DateDiffDay(cDate1, cDate2) < 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Liberado para Produção"

                CASE DateDiffDay(cDate1, cDate2) = 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Liberado para Produção"

                    //SomaHoras(ElapTime(AllTrim(aMultLogUser[y][4]), cDayHours), ElapTime(AllTrim(aMultLogUser[a][4]), cDayHours))

                CASE DateDiffDay(cDate1, cDate2) > 1
                    cDayCount  := DateDiffDay(cDate1, cDate2)
                    For z:=1  To cDayCount

                        cDayHours := SomaHoras(cDayHours ,cDayAdd)

                    Next z

                    cHourCount := CVALTOCHAR(ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4])))
                    cHourCount := CVALTOCHAR(cDayCount) + " dias e " + cHourCount + " horas"

                    cDtDif := cHourCount
                    
                RETURN cDtDif += ". Liberado para Produção"

            ENDCASE

        // Bloco de calculo de tempo caso o Pedido esteja parado na liberação da Engenharia.    
        CASE (aMultLogUser[y][5]) = "ENG" .or. (aMultLogUser[y][5]) = "ENP"
            
            If(aMultLogUser[a][1]) = " "
                (aMultLogUser[a][1]) := "ENGENHARIA"
                (aMultLogUser[a][2]) := "-"
                (aMultLogUser[a][4]) := TIME()
                (aMultLogUser[a][5]) := "ENG"
            EndIf

            DO CASE

                CASE DateDiffDay(cDate1, cDate2) < 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Aguardando Lib. Engenharia"

                CASE DateDiffDay(cDate1, cDate2) = 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Aguardando Lib. Engenharia"

                    //SomaHoras(ElapTime(AllTrim(aMultLogUser[y][4]), cDayHours), ElapTime(AllTrim(aMultLogUser[a][4]), cDayHours))

                CASE DateDiffDay(cDate1, cDate2) > 1
                    cDayCount  := DateDiffDay(cDate1, cDate2)
                    For z:=1  To cDayCount

                        cDayHours := SomaHoras(cDayHours ,cDayAdd)

                    Next z

                    cHourCount := CVALTOCHAR(ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4])))
                    cHourCount := CVALTOCHAR(cDayCount) + " dias e " + cHourCount + " horas"

                    cDtDif := cHourCount
                    
                RETURN cDtDif += ". Aguardando Lib. Engenharia"

            ENDCASE

        // Bloco de calculo de tempo caso o Pedido esteja parado na liberação de Projeto.    
        CASE (aMultLogUser[y][5]) = "PRJ"

            
            If(aMultLogUser[a][1]) = " "
                (aMultLogUser[a][1]) := "PROJETO"
                (aMultLogUser[a][2]) := "-"
                (aMultLogUser[a][4]) := TIME()
                (aMultLogUser[a][5]) := "PRJ"
            EndIf

            DO CASE

                CASE DateDiffDay(cDate1, cDate2) < 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Aguardando Lib. Projeto"

                CASE DateDiffDay(cDate1, cDate2) = 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Aguardando Lib. Projeto"

                    //SomaHoras(ElapTime(AllTrim(aMultLogUser[y][4]), cDayHours), ElapTime(AllTrim(aMultLogUser[a][4]), cDayHours))

                CASE DateDiffDay(cDate1, cDate2) > 1
                    cDayCount  := DateDiffDay(cDate1, cDate2)
                    For z:=1  To cDayCount

                        cDayHours := SomaHoras(cDayHours ,cDayAdd)

                    Next z

                    cHourCount := CVALTOCHAR(ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4])))
                    cHourCount := CVALTOCHAR(cDayCount) + " dias e " + cHourCount + " horas"

                    cDtDif := cHourCount

                RETURN cDtDif += ". Aguardando Lib. Projeto."

            ENDCASE
        // Bloco de calculo de tempo caso o Pedido esteja parado na liberação de Credito. 
        CASE (aMultLogUser[y][5]) = "CRE" .or. (aMultLogUser[y][5]) = "CRP"

            DO CASE

                CASE DateDiffDay(cDate1, cDate2) < 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Aguardando Lib. Credito"

                CASE DateDiffDay(cDate1, cDate2) = 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Aguardando Lib. Credito"

                    //SomaHoras(ElapTime(AllTrim(aMultLogUser[y][4]), cDayHours), ElapTime(AllTrim(aMultLogUser[a][4]), cDayHours))

                CASE DateDiffDay(cDate1, cDate2) > 1
                    cDayCount  := DateDiffDay(cDate1, cDate2)
                    For z:=1  To cDayCount

                        cDayHours := SomaHoras(cDayHours ,cDayAdd)

                    Next z

                    cHourCount := CVALTOCHAR(ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4])))
                    cHourCount := CVALTOCHAR(cDayCount) + " dias e " + cHourCount + " horas"

                    cDtDif := cHourCount
                    
                RETURN cDtDif += ". Aguardando Lib. Credito"

            ENDCASE

        // Bloco de calculo de tempo caso o Pedido esteja parado na liberação Comercial. 
        CASE (aMultLogUser[y][5]) = "COM" .or. (aMultLogUser[y][5]) = "COP"

            DO CASE

                CASE DateDiffDay(cDate1, cDate2) < 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Aguardando Lib. Comercial"

                CASE DateDiffDay(cDate1, cDate2) = 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

                    cDtDif := cHourCount

                    RETURN cDtDif += ". Aguardando Lib. Comercial"

                CASE DateDiffDay(cDate1, cDate2) > 1
                    cDayCount  := DateDiffDay(cDate1, cDate2)
                    For z:=1  To cDayCount

                        cDayHours := SomaHoras(cDayHours ,cDayAdd)

                    Next z

                    cHourCount := CVALTOCHAR(ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4])))
                    cHourCount := CVALTOCHAR(cDayCount) + " dias e " + cHourCount + " horas"

                    cDtDif := cHourCount

                RETURN cDtDif += ". Aguardando Lib. Comercial"

            ENDCASE
        // Bloco de calculo de tempo caso o Pedido esteja aguardando a liberação da Equipe de Vendas. 
        CASE (aMultLogUser[y][5]) = "PED" .or. (aMultLogUser[y][5]) = "PEP"

            DO CASE

                CASE DateDiffDay(cDate1, cDate2) < 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))
                    cDtDif := cHourCount

                    RETURN cDtDif += " Aguardando Vendedor"

                CASE DateDiffDay(cDate1, cDate2) = 1

                    cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))
                    cDtDif := cHourCount

                    RETURN cDtDif += " Aguardando Vendedor"

                CASE DateDiffDay(cDate1, cDate2) > 1
                    cDayCount  := DateDiffDay(cDate1, cDate2)
                    For z:=1  To cDayCount

                        cDayHours := SomaHoras(cDayHours ,cDayAdd)

                    Next z

                    cHourCount := CVALTOCHAR(ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4])))
                    cHourCount := CVALTOCHAR(cDayCount) + " dias e " + cHourCount + " horas"

                    cDtDif := cHourCount
                    
                RETURN cDtDif += " Aguardando Vendedor"

            ENDCASE

        CASE DateDiffDay(cDate1, cDate2) < 1

            cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

            RETURN cDtDif := cHourCount

        CASE DateDiffDay(cDate1, cDate2) = 1

            cHourCount  := ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4]))

            RETURN cDtDif := cHourCount

            //SomaHoras(ElapTime(AllTrim(aMultLogUser[y][4]), cDayHours), ElapTime(AllTrim(aMultLogUser[a][4]), cDayHours))

        CASE DateDiffDay(cDate1, cDate2) > 1
            cDayCount  := DateDiffDay(cDate1, cDate2)
            For z:=1  To cDayCount

                cDayHours := SomaHoras(cDayHours ,cDayAdd)

            Next z

            cHourCount := CVALTOCHAR(ElapTime(AllTrim(aMultLogUser[y][4]), AllTrim(aMultLogUser[a][4])))
            cHourCount := CVALTOCHAR(cDayCount) + " dias e " + cHourCount + " horas"

            cDtDif := cHourCount

        RETURN cDtDif

    ENDCASE

return cDtDif

static function fSQLOrdem()

    local aOrcamento        := oTrackOrc:get("aOrcamento")
    local cOrcamento        := AllTrim(aOrcamento[1][1])
    local cOrdemDados       := ""
    local aOrdem            := oTrackOrc:get("aOrdem")
    local cOrdem            := AllTrim(aOrdem[1][1])
    local aOrdemMult        := {}
    local cPedido          := ""
    local aTempOper         := {}
    local z                 := 0
    local x                 := 0
    local y                 := 0
    private cDataEmiPed     := ""
    private cDataEntPed     := ""
    private cCodClient      := ""
    private cRazaoSocial    := ""
    private cNomeReduzi     := ""
    private cCNPJ           := ""
    private aArrayOrdem     := {}
    private cRoteiroOP      := {}

    //Consulta SUA e pega Codigo do cliente e Data da emissão do Orcamento.
        BEGINSQL ALIAS "SQL_SUA"
        SELECT  UA_NUMSC5
                    FROM SUA010
                    WHERE UA_FILIAL = %xFilial:SUA%
                        AND UA_NUM = %EXP:cOrcamento%
                        //AND SUA.%notDel%
        ENDSQL

        //Se houve dados
        If ! SQL_SUA->(EoF())

            SQL_SUA->( dbGoTop() )

                cPedido := SQL_SUA->UA_NUMSC5

            SQL_SUA->( dbCloseArea() )
            
        Else

            MsgStop("Nao foram encontrados Dados das Ordens de Produção!", "Atencao")
            SQL_SUA->( dbCloseArea() )

        EndIf

        
    
    //Consulta SC5 e pega Codigo do cliente e Data da emissão do pedido.
        BEGINSQL ALIAS "SQL_SC5"
        SELECT  C5_CLIENT,
                CONVERT(VARCHAR(10),CONVERT(DATE,C5_EMISSAO,103),103) AS C5_EMISSAO
            FROM %table:SC5% SC5
            WHERE  C5_NUM = %EXP:cPedido%
                AND C5_FILIAL = %xFilial:SC5%
                AND SC5.%notDel%
        ENDSQL

        //Se houve dados
        If ! SQL_SC5->(EoF())

            SQL_SC5->( dbGoTop() )

                cCodClient  := SQL_SC5->C5_CLIENT
                cDataEmiPed := SQL_SC5->C5_EMISSAO

            SQL_SC5->( dbCloseArea() )

            
            //Consulta SA1 e pega Razão social, Nome Reduz e CNPJ.
                BEGINSQL ALIAS "SQL_SA1"
                    SELECT  A1_NOME,
                            A1_NREDUZ,
                            A1_CGC
                        FROM %table:SA1% SA1
                        WHERE  A1_COD = %EXP:cCodClient%
                            AND A1_FILIAL = %xFilial:SA1%
                            AND SA1.%notDel%
                ENDSQL

                //Se houve dados
                If ! SQL_SA1->(EoF())

                    SQL_SA1->( dbGoTop() )

                        cRazaoSocial    := SQL_SA1->A1_NOME
                        cNomeReduzi     := SQL_SA1->A1_NREDUZ
                        cCNPJ           := SQL_SA1->A1_CGC

                    SQL_SA1->( dbCloseArea() )

                Else

                    MsgStop("Nao foram encontrados Dados do Ciente!", "Atencao")
                    SQL_SA1->( dbCloseArea() )

                EndIf

            //Consulta SC2 e pega Numero da OP, Data Emissão da OP, Data da Previsão de Entrega da OP e Data de Entrega real da OP.
                    BEGINSQL ALIAS "SQL_SC2"
                        SELECT  CONCAT(C2_NUM, C2_ITEM, C2_SEQUEN) AS C2_OP                
                            FROM %table:SC2% SC2
                            WHERE  C2_PEDIDO = %EXP:cPedido%
                                AND C2_FILIAL = %xFilial:SC2%
                                AND SC2.%notDel%
                    ENDSQL

                    If ! SQL_SC2->(EoF())
                    
                        SQL_SC2->( dbGoTop() )

                            While ! SQL_SC2->(EoF())

                                cConcatOrdem  :=  SQL_SC2->C2_OP 

                                aadd( aArrayOrdem, StrTokArr(cConcatOrdem, ",") )

                                SQL_SC2->(DbSkip())

                            EndDo

                        SQL_SC2->( dbCloseArea() )
                        
                    Else

                        MsgStop("Nao foram encontrados Dados da OP!", "Atencao")
                        SQL_SC2->( dbCloseArea() )

                    EndIf

            //Consulta SC6 e pega os primeiros dados.
                BEGINSQL ALIAS "SQL_SC6"
                    SELECT  CONVERT(VARCHAR(10),CONVERT(DATE,C6_ENTREG,103),103) AS C6_ENTREG

                        FROM %table:SC6% SC6
                        WHERE  C6_NUM = %EXP:cPedido%
                            AND C6_ITEM BETWEEN '01' and '99'
                            AND C6_FILIAL = %xFilial:SC6%
                            AND SC6.%notDel%
                ENDSQL

                //Se houve dados
                If ! SQL_SC6->(EoF())

                    SQL_SC6->( dbGoTop() )

                        cDataEntPed     := SQL_SC6->C6_ENTREG

                    SQL_SC6->( dbCloseArea() )

                Else

                    MsgStop("Nao foram encontradas as Datas das OP's!", "Atencao")
                    SQL_SC6->( dbCloseArea() )

                EndIf

            


            //Consulta SC2 e pega Numero da OP, Data Emissão da OP, Data da Previsão de Entrega da OP e Data de Entrega real da OP.
                BEGINSQL ALIAS "SQL_SC2"
                    SELECT  CONCAT(C2_NUM, C2_ITEM, C2_SEQUEN) AS C2_OP,
                            C2_EMISSAO,
                            C2_DATPRF,
                            C2_DATRF,
                            C2_ROTEIRO,
                            C2_PRODUTO   
                        FROM %table:SC2% SC2
                        WHERE  C2_PEDIDO = %EXP:cPedido%
                            AND CONCAT(C2_NUM, C2_ITEM, C2_SEQUEN) = %EXP:cOrdem%
                            AND C2_FILIAL = %xFilial:SC2%
                            AND SC2.%notDel%
                ENDSQL

                If ! SQL_SC2->(EoF())
                
                    SQL_SC2->( dbGoTop() )

                        While ! SQL_SC2->(EoF())

                            aOrdemItens  :=     SQL_SC2->C2_OP + "," +;
                                                SQL_SC2->C2_EMISSAO + "," +;
                                                SQL_SC2->C2_DATPRF + "," +;
                                                SQL_SC2->C2_DATRF + "," +;
                                                SQL_SC2->C2_ROTEIRO + "," +;
                                                SQL_SC2->C2_PRODUTO
                            
                            //cNumOP          := SQL_SC2->C2_OP
                            //cDataEmiOP      := SQL_SC2->C2_EMISSAO
                            //cDataPrevOP     := SQL_SC2->C2_DATPRF
                            //cDataEntOP      := SQL_SC2->C2_DATRF

                            aadd( aOrdemMult, StrTokArr(aOrdemItens, ",") )

                            SQL_SC2->(DbSkip())

                        EndDo

                    SQL_SC2->( dbCloseArea() )
                    
                Else

                    MsgStop("Nao foram encontrados Dados completos das OP's!", "Atencao")
                    SQL_SC2->( dbCloseArea() )

                EndIf


            //Consulta SG2 e pega dos dados das operações e descrição das mesmas.
                BEGINSQL ALIAS "SQL_SG2"
                SELECT  G2_OPERAC,
                        G2_DESCRI
                    FROM %table:SG2% SG2
                    WHERE  G2_CODIGO = %EXP:aOrdemMult[1][5]%
                        AND G2_PRODUTO = %EXP:aOrdemMult[1][6]%
                        AND G2_FILIAL = %xFilial:SG2%
                        AND SG2.%notDel%
                ENDSQL

                //Se houve dados
                If ! SQL_SG2->(EoF())

                    SQL_SG2->( dbGoTop() )

                        While ! SQL_SG2->(EoF())

                            cRoteDesc       :=  SQL_SG2->G2_OPERAC + "," +;
                                                SQL_SG2->G2_DESCRI

                            aadd( cRoteiroOP, StrTokArr(cRoteDesc, ",") )

                            SQL_SG2->(DbSkip())

                        EndDo

                    SQL_SG2->( dbCloseArea() )

                Else

                    cRoteiroOP := "Sem Dados" + "," + "OP Não iniciada."

                    MsgStop("Operação não iniciada, sem dados para exibir!", "Atencao")
                    SQL_SG2->( dbCloseArea() )
                    BREAK

                EndIf

            //Consulta SH6 e pega O Código do Operador e o tempo decorrido na operação.
                BEGINSQL ALIAS "SQL_SH6"
                SELECT  H6_TEMPO,
                        H6_OPERADO
                            FROM %table:SH6% SH6 
                                WHERE H6_FILIAL = %xFilial:SH6% 
                                        AND H6_OP = %EXP:cOrdem%
                ENDSQL

                //Se houve dados
                If ! SQL_SH6->(EoF())

                    SQL_SH6->( dbGoTop() )

                        While ! SQL_SH6->(EoF())

                            cTempOper   :=  SQL_SH6->H6_TEMPO + "," +;
                                            SQL_SH6->H6_OPERADO

                            aadd( aTempOper, StrTokArr(cTempOper, ",") )

                            SQL_SH6->(DbSkip())

                        EndDo

                    SQL_SH6->( dbCloseArea() )

                    If Len(cRoteiroOP) <> Len(aTempOper)

                        l := Len(cRoteiroOP) - Len(aTempOper)

                        While l > 0

                            cTempOper := "--:--:--" + "," + "Operação não iniciada."
                            aadd( aTempOper, StrTokArr(cTempOper, ",") )
                            l := l - 1

                        EndDo

                    EndIf

                Else

                    For z:=1  To Len(cRoteiroOP)

                        cTempOper := "--:--:--" + "," + "OP Não iniciada."

                        aadd( aTempOper, StrTokArr(cTempOper, ",") )

                    Next z

                    MsgStop("Nao foram encontrados registros!", "Atencao")
                    SQL_SH6->( dbCloseArea() )

                EndIf

        Else

            MsgStop("Não foram encontrados dados do Cliente e Data de Emissão!", "Atencao")
            SQL_SC5->( dbCloseArea() )

        EndIf

    

    // Constroi HTML que será inserido na pagina com os dados.
        // Dados da SC5 e SC6
            cOrdemDados +=;
            "<div class='container'>"                                                                               +;
                "<div class='fluid-container'>"                                                                     +;
                    "<h3>Dados do Pedido</h3>"                                                                      +;
                    "<div class='input col-2'><label for='pedido'>          </label>"                               +;
                            "<button id='btnvoltar' class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<voltar>`,"  +;
                            "`"+ cOrcamento +"`)'>VOLTAR</button>"                                                  +;
                        "</div>"                                                                                    +;
                "</div>"                                                                                            +;
                "<div class='row justify-content-center'>"                                                          +;
                    "<div class='col-2'>"                                                                           +;
                        "<label for='pedido'>N° Pedido</label> "                                                    +;
                        "<input type='text' class='form-control' id='pedido' value='"+ cPedido +"' readonly>"       +;
                    "</div>"                                                                                        +;
                    "<div class='col-3'>"                                                                           +;
                        "<label for='pedido'>Data de Emissão</label> "                                              +;
                        "<input type='text' class='form-control' id='pedido' value='"+ cDataEmiPed +"' readonly>"   +;
                    "</div>"                                                                                        +;
                    "<div class='col-3'>"                                                                           +;
                        "<label for='pedido'>Data de Entrega</label> "                                              +;
                        "<input type='text' class='form-control' id='pedido' value='"+ cDataEntPed +"' readonly>"   +;
                    "</div>"                                                                                        +;
                "</div>"                                                                                            +;
                "</div>"                                                                                            +;
            "</div>"

    // Dados da SA1
        cOrdemDados +=;
        "<div class='container'>"                                                                               +;
            "<div class='row justify-content-center'>"                                                          +;
                "<div class='col-2'>"                                                                           +;
                    "<label for='pedido'>Cliente</label> "                                                      +;
                    "<input type='text' class='form-control' id='pedido' value='"+ cCodClient +"' readonly>"    +;
                "</div>"                                                                                        +;
                "<div class='col-3'>"                                                                           +;
                    "<label for='pedido'>Razão Social</label> "                                                 +;
                    "<input type='text' class='form-control' id='pedido' value='"+ cRazaoSocial +"' readonly>"  +;
                "</div>"                                                                                        +;
                "<div class='col-3'>"                                                                           +;
                    "<label for='pedido'>Nome Reduzido</label> "                                                +;
                    "<input type='text' class='form-control' id='pedido' value='"+ cNomeReduzi +"' readonly>"   +;
                "</div>"                                                                                        +;
                "<div class='col-3'>"                                                                           +;
                    "<label for='pedido'>CNPJ</label> "                                                         +;
                    "<input type='text' class='form-control' id='pedido' value='"+ cCNPJ +"' readonly>"         +;
                "</div>"                                                                                        +;
            "</div>"                                                                                            +;
        "</div>"                                                                                                
    //Alimenta o menu dropdown com os númenos das ops se houver dados.
        if !Empty(aArrayOrdem)
            cOrdemDados +=;
            "<div class='container'>"                                                                               +;
                "<div class='dropdown'>"                                                                            +;
                    "<button class='dropbtn'>Ordens de Produção</button>"                                           +;
                    "<div class='dropdown-content'>"                                                                +;
                        "<div class='input-group mb-3'>"
        
                        For x:=1 To Len(aArrayOrdem)
                            cOrdemDados +=;
                                "<div class='input-group mb-4'>"                                                    +;
                                    "<input type='text' class='form-control' aria-describedby='basic-addon2' "      +;
                                    " id='ordem' value='" + aArrayOrdem[x][1] + "' readonly>"                       +;
                                    "<div class='input-group-append'>"                                              +;
                                        "<button class='btn btn-outline-secondary' "                                +;
                                        "onclick='twebchannel.jsToAdvpl(`<ordem>`,`" + aArrayOrdem[x][1] + "`)'>"   +;
                                        "IR</button>"                                                               +;
                                    "</div>"                                                                        +;
                                "</div>"
                        Next x
                            cOrdemDados +=;
                    "</div>"                                                                                        +;
                "</div>"                                                                                            +;
            "</div>"
        EndIf

    // Constroi HTML que será inserido na pagina com os dados.
    // Dados da SC2 e SG2
        cOrdemDados +=;
        "<div class='container'>"                                                                                           +;
            "<div class='row justify-content-center'>"                                                                      +;
                "<div class='col-2'>"                                                                                       +;
                    "<label >N° da OP</label> "                                                                             +;
                    "<input type='text' class='form-control' id='numOp' value='"+ aOrdemMult[1][1] +"' readonly>"           +;
                "</div>"                                                                                                    +;
                "<div class='col-3'>"                                                                                       +;
                    "<label >Produto</label> "                                                                              +;
                    "<input type='text' class='form-control' id='produto' value='"+ aOrdemMult[1][6] +"' readonly>"         +;
                "</div>"                                                                                                    +;
            "</div>"                                                                                                        +;
        "</div>"   +;
        "</br>"   +;
            "<table class='table table-bordered table-striped table-dark'>"+;
                    "<tr><td>Operação</td>"+;
                        "<td>Descrição</td>"+;
                        "<td>Tempo</td>"+;
                        "<td>Operador</td>"+;
                        "</tr>"   //Fechamos o cabeçalho
                        For y:=1  To Len(cRoteiroOP)
                        cOrdemDados +=;
                            "<tr><td>'"+ cRoteiroOP[y][1] +"'</td>"+;
                                "<td>'"+ cRoteiroOP[y][2] +"'</td>"+;
                                "<td>'"+ aTempOper[y][1] +"'</td>"+;
                                "<td>'"+ aTempOper[y][2] +"'</td>"+;
                            "</tr>"
                        Next y
                    

                    


    oWebChannel:advplToJS("<track-orcamento>", cOrdemDados)

return

//Função que altera os estagios de liberação.
static function fStComercial()
    local aComercial    := oTrackOrc:get("aComercial")
    local cRecno        := AllTrim(aComercial[1][1])
    Local cStatus       := AllTrim(aComercial[1][2])
    local aZRP          := ZRP->(GetArea())
    local aSUA          := SUA->(GetArea())
    local aSZB          := SZB->(GetArea())
    //local cDATETIME 	:= DTOS(DATE()) + " " + cVALTOCHAR(TIME())
    private cOrcamento  := ""
    private cRetornoOrc := ""
    private aMultLog    := {}
    

    nRecno := Val(cRecno)

    //Consulta a ZRP e pega o número do Orçamento.
    dbSelectArea("ZRP")
        ZRP->(dbGoTo(nRecno))

        RecLock('ZRP', .F.)

            Begin Transaction
                cOrcamento := ZRP->ZRP_NUMERO
            End Transaction

        ZRP->(msUnlock())

        ZRP->( dbCloseArea() )

    RestArea(aZRP)

    //Consulta a SUA e pega o número do Pedido e vendedor.

    cRetornoOrc := cOrcamento
    If !Empty(cRetornoOrc)
        dbSelectArea("SUA")
            SUA->(dbSetOrder(1))
            SUA->(dbSeek(xFilial("SUA") + cRetornoOrc))

            Begin Transaction
                cPedido     := SUA->UA_NUMSC5
                cVendedor   := SUA->UA_VEND
            End Transaction

            SUA->(msUnlock())
            SUA->(dbCloseArea())

        RestArea(aSUA)
    EndIf

    //Tratativa dos Estagios de Liberação conforme o Pedido avança ou retrocede nas liberações
    If cStatus = "PRJLIB" // liberação do projeto para Engenharia
        cStatus := "ENP"
        dbSelectArea("ZRP")
            ZRP->(dbGoTo(nRecno))

            RecLock('ZRP', .F.)

                Begin Transaction
                    ZRP->ZRP_STATUS		:= cStatus
                End Transaction

            ZRP->(msUnlock())

            ZRP->( dbCloseArea() )

        RestArea(aZRP)

    ElseIf cStatus = "ENGLIB" // liberação da Engenharia para Faturamento
        cStatus := "PRD"
        dbSelectArea("ZRP")
            ZRP->(dbGoTo(nRecno))

            RecLock('ZRP', .F.)

                Begin Transaction
                    ZRP->ZRP_STATUS		:= cStatus
                End Transaction

            ZRP->(msUnlock())

            ZRP->( dbCloseArea() )

        RestArea(aZRP)

    ElseIf cStatus = "ENPLIB" // liberação da Engenharia para Faturamento
        cStatus := "PRP"
        dbSelectArea("ZRP")
            ZRP->(dbGoTo(nRecno))

            RecLock('ZRP', .F.)

                Begin Transaction
                    ZRP->ZRP_STATUS		:= cStatus
                End Transaction

            ZRP->(msUnlock())

            ZRP->( dbCloseArea() )

        RestArea(aZRP)

    ElseIf cStatus = "VAIPRJ" // liberação da Engenharia para Faturamento
        cStatus := "PRJ"
        dbSelectArea("ZRP")
            ZRP->(dbGoTo(nRecno))

            RecLock('ZRP', .F.)

                Begin Transaction
                    ZRP->ZRP_STATUS		:= cStatus
                End Transaction

            ZRP->(msUnlock())

            ZRP->( dbCloseArea() )

        RestArea(aZRP)

    ElseIf cStatus = "SAIPRJ" // liberação da Engenharia para Faturamento
        cStatus := "PED"
        dbSelectArea("ZRP")
            ZRP->(dbGoTo(nRecno))

            RecLock('ZRP', .F.)

                Begin Transaction
                    ZRP->ZRP_STATUS		:= cStatus
                End Transaction

            ZRP->(msUnlock())

            ZRP->( dbCloseArea() )

        RestArea(aZRP)

    Else


        If cStatus = "PED"
            cStatus := "COM"

        ElseIf cStatus = "COM"
            cStatus := "PED"

        ElseIf cStatus = "CRE"
            cStatus := "PED"

        ElseIf cStatus = "ENG" .or. cStatus = "PRD"
            cStatus     := "PED"
            cEmailLib   := GetMV("MV_EMAILPR")

            dbSelectArea("SZB")
                SZB->(dbGoTo(nRecno))
                SZB->(dbSetOrder(1))
                SZB->(dbSeek(xFilial("SZB") + cVendedor))

                    Begin Transaction
                        cEmail := cEmailLib + "; " + Alltrim(SZB->ZB_EMAIL) 
                    End Transaction            

                SZB->( dbCloseArea() )

            RestArea(aSZB)

            //Monta o Html para enviar a email informando aos vendedores que um pedido foi estornado
            cHTML :=    "<!DOCTYPE html>"+;
                        "<html lang='en'>"+;
                            "<body>"+;
                                "</br>"+;
                                "<h3>O Pedido " + cPedido + ", referente ao orçamento " + cRetornoOrc + " foi rejeitado pelo setor de Engenharia.</h3>"+;
                            "</body>"
            //Chama a função de envio dentro do do fonte Trackemail passando o cHTMLe o cEmail como parâmetro.       
            u_Trackemail(cHTML,cEmail)

        ElseIf cStatus = "PEP"
            cStatus := "COP"

        ElseIf cStatus = "COP"
            cStatus := "PEP"

        ElseIf cStatus = "CRP"
            cStatus := "PEP"
        
        ElseIf cStatus = "ENP" .or. cStatus = "PRP"
            cStatus := "PEP"
            cEmailLib   := GetMV("MV_EMAILPR")

            dbSelectArea("SZB")
                SZB->(dbGoTo(nRecno))
                SZB->(dbSetOrder(1))
                SZB->(dbSeek(xFilial("SZB") + cVendedor))

                    Begin Transaction
                        cEmail := cEmailLib + "; " + Alltrim(SZB->ZB_EMAIL)
                    End Transaction            

                SZB->( dbCloseArea() )

            RestArea(aSZB)

            //Monta o Html para enviar a email informando aos vendedores que um pedido foi estornado
            cHTML :=    "<!DOCTYPE html>"+;
                        "<html lang='en'>"+;
                            "<body>"+;
                                "</br>"+;
                                "<h3>O Pedido " + cPedido + ", referente ao orçamento " + cRetornoOrc + " foi rejeitado pelo setor de Engenharia.</h3>"+;
                            "</body>"
            //Chama a função de envio dentro do do fonte Trackemail passando o cHTMLe o cEmail como parâmetro.       
            u_Trackemail(cHTML,cEmail)

        ElseIf cStatus = "PRJ"
            cStatus := "PEP"
            cEmailLib   := GetMV("MV_EMAILPR")

            dbSelectArea("SZB")
                SZB->(dbGoTo(nRecno))
                SZB->(dbSetOrder(1))
                SZB->(dbSeek(xFilial("SZB") + cVendedor))

                    Begin Transaction
                        cEmail := cEmailLib + "; " + Alltrim(SZB->ZB_EMAIL)
                    End Transaction            

                SZB->( dbCloseArea() )

            RestArea(aSZB)

            //Monta o Html para enviar a email informando aos vendedores que um pedido foi estornado
            cHTML :=    "<!DOCTYPE html>"+;
                        "<html lang='en'>"+;
                            "<body>"+;
                                "</br>"+;
                                "<h3>O Pedido " + cPedido + ", referente ao orçamento " + cRetornoOrc + " foi extornado pelo setor de projetos.</h3>"+;
                            "</body>"
            //Chama a função de envio dentro do do fonte Trackemail passando o cHTMLe o cEmail como parâmetro.       
            u_Trackemail(cHTML,cEmail)

        ElseIf cStatus = "ATD"
            cStatus := "PED"

        Else
            cStatus := "PED"

        EndIf

        dbSelectArea("ZRP")

            ZRP->(dbGoTo(nRecno))

                RecLock('ZRP', .F.)
                    Begin Transaction
                        ZRP->ZRP_STATUS		:= cStatus
                    End Transaction
                ZRP->(msUnlock())

            ZRP->( dbCloseArea() )

        RestArea(aZRP)


    EndIf

    // Altera o campo STATE da tabela ZRP e atualiza com a ultima atualização no estado do pedido/orçamento.
	aadd( aMultLog, StrTokArr(cOrcamento, ",") )
	u_UpdateZrp(aMultLog)


    oWebChannel:advplToJS("<reload-page>", cRetornoOrc)


return


// Classe WebComponent de teste
class TrackOrc 
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
Method Constructor() class TrackOrc
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
Method OnInit(webengine, url) class TrackOrc
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
Method Template() class TrackOrc

    local cHTML         := ""

    cHTML   +=;
    cHTML   +=" <script src='twebchannel.js'></script> "                                                                                                    + CRLF
    cHTML   +=" <script> "                                                                                                                                  + CRLF
    cHTML   +=    " var track_Orcamento "                                                                                                                   + CRLF
    cHTML   +=    " var track_ordem "                                                                                                                       + CRLF
    cHTML   +=    " var reload_page "                                                                                                                       + CRLF
    cHTML   +=    " var voltar "                                                                                                                            + CRLF
    cHTML   +=    " window.onload = function() { "                                                                                                          + CRLF
    cHTML   +=        " track_Orcamento = document.getElementById('track-Orcamento'); "                                                                     + CRLF
    cHTML   +=        " track_ordem = document.getElementById('track-Ordem'); "                                                                             + CRLF
    cHTML   +=        " reload_page = document.getElementById('reload-page'); "                                                                             + CRLF
    cHTML   +=        " voltar = document.getElementById('voltar'); "                                                                                       + CRLF
    cHTML   +=        "// Estabelece conexao entre o AdvPL e o JavaScript via WebSocket"                                                                    + CRLF
    cHTML   +=        " twebchannel.connect( () => { console.log('Websocket Connected!'); } ); "                                                            + CRLF
    cHTML   +=        " twebchannel.advplToJs = function(key, value) { "                                                                                    + CRLF
    cHTML   +=           "// ----------------------------------------------------------"                                                                    + CRLF
    cHTML   +=            "// Insira aqui o tratamento para as mensagens vindas do AdvPL"                                                                   + CRLF
    cHTML   +=            "// ----------------------------------------------------------"                                                                   + CRLF
    cHTML   +=            " if (key === '<script>') { "                                                                                                     + CRLF
    cHTML   +=                " let tag = document.createElement('script'); "                                                                               + CRLF
    cHTML   +=                " tag.setAttribute('type', 'text/javascript'); "                                                                              + CRLF
    cHTML   +=                " tag.innerText = value; "                                                                                                    + CRLF
    cHTML   +=                " document.getElementsByTagName('head')[0].appendChild(tag); "                                                                + CRLF
    cHTML   +=            " } "                                                                                                                             + CRLF
    cHTML   +=            " else if(key === '<track-orcamento>') { "                                                                                        + CRLF
    cHTML   +=                " track_Orcamento.innerHTML  = value "                                                                                        + CRLF
    cHTML   +=            " } "                                                                                                                             + CRLF
    cHTML   +=            " else if(key === '<track-ordem>') { "                                                                                            + CRLF
    cHTML   +=                " track_ordem.innerHTML   = value "                                                                                           + CRLF
    cHTML   +=            " } "                                                                                                                             + CRLF
    cHTML   +=            " else if((key === '<reload-page>')){ "                                                                                           + CRLF
    cHTML   +=                " document.getElementById('btnvoltar').click(); "                                                                      + CRLF
    cHTML   +=            " } "                                                                                                                             + CRLF
    cHTML   +=        " } "                                                                                                                                 + CRLF
    cHTML   +=   " }; "                                                                                                                                     + CRLF
    cHTML   +=" </script> "                                                                                                                                 + CRLF
    cHTML   +=" <body style='background-color: #d1e6cc;'> "                                                                                                 + CRLF
    cHTML   +=    " <div class='flex-contariner'> "                                                                                                         + CRLF
    cHTML   +=        " <nav class='navbar navbar-dark justify-content-center' style='background-color: #217b4b;'> "                                        + CRLF
    cHTML   +=                " <div> "                                                                                                                     + CRLF
    cHTML   +=                  " <a class='navbar-brand'>RASTREAMENTO: Orçamentos</a> "                                                                    + CRLF
    cHTML   +=                  " <form class='form-inline' id='trackFormOrcamento' onSubmit='return onClickSubmit(event, trackFormOrcamento);'> "          + CRLF
    cHTML   +=                      " <input class='form-control mr-sm-2' type='search' placeholder='Orcamento' id='Orcamento' name='dados'> "              + CRLF
    cHTML   +=                      " <button hidden class='btn btn-outline-success my-2 my-sm-0' id='btnSubmit' type='submit'>Orçamento</button> "         + CRLF
    cHTML   +=                  " </form> "                                                                                                                 + CRLF
    cHTML   +=                "</div>"                                                                                                                      + CRLF
    cHTML   +=                " <div> "                                                                                                                     + CRLF
    cHTML   +=                " </div> "                                                                                                                    + CRLF
    cHTML   +=        " </nav> "                                                                                                                            + CRLF
    cHTML   +=    " </div> "                                                                                                                                + CRLF
    cHTML   +=    " <div id='track-Orcamento'></div> "                                                                                                      + CRLF
    cHTML   +=    " <div id='track-Ordem'></div> "                                                                                                          + CRLF
    cHTML   +=" </body> "

return cHTML

// Scripts
Method Script() class TrackOrc
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
                document.getElementById("Orcamento").focus()
                return false
            }

        </script>
    EndContent
return cScript   

// Estilos
Method Style() class TrackOrc
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
            background-color: #04AA6D;
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
Method Get(cVarname) class TrackOrc
    // Recupera valor do array global (State)
    local nPosBase := AScan( ::mainData, {|x| x[1] == cVarname} )
    if nPosBase > 0
        return ::mainData[nPosBase, 2]
    endif
return ""

// Setter [*Getter_and_Setter]
Method Set(cVarname, xValue, bUpdate) class TrackOrc
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
Method SaveFile(cContent) class TrackOrc
    local nHdl := fCreate(iif(::GetOS()=="UNIX", "l:", "") + ::mainHTML)
    if nHdl > -1
        fWrite(nHdl, cContent)
        fClose(nHdl)
    else
        return .F.
    endif
return .T.

// Retorna Sistema Operacional em uso
Method GetOS() class TrackOrc
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
