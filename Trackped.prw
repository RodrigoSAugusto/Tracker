#include "totvs.ch"
  
/*{Protheus.doc} u_TrackPed()
    Funcao utilizando TWebEngine/TWebChannel para rastrear pedidos
    @author Rodrigo Augusto
    @since 21/06/2022
    @see: http://tdn.totvs.com/display/tec/twebengine
          http://tdn.totvs.com/display/tec/twebchannel
    @observation:
          Compativel com SmartClient Desktop(Qt);
*/


User function TrackPed()

    local oWebEngine
    local aSize             := MsAdvSize()
    local oModal

    //variaveis da consulta Pedido/Cliente
    private cCodClient      := ""
    private cRazaoSocial    := ""
    private cNomeReduzi     := ""
    private cCNPJ           := ""
    private cDataEmiPed     := ""
    private cDataEntPed     := ""
    private cNumOP          := ""
    private cConcatOrdem    := {}
    private aArrayOrdem     := {}

    //Variáveis da colsulta de Ordem de Produção
    private aOrdemItens     := {}
    private cOrdemDados     := ""
    private cDataEmiOP      := ""
    private cDataPrevOP     := ""
    private cDataEntrOP     := ""
    private cRoteiroOP      := {}
    private cProdutoOP      := ""
    private cDescriOP       := ""
    private cAptOperacao    := ""


    

    private oWebChannel, oTrackPed

    oModal := MSDialog():New(aSize[7],0,aSize[6],aSize[5], "Página Local",,,,,,,,,.T./*lPixel*/)
        // WebSocket (comunicacao AdvPL x JavaScript)
        oWebChannel := TWebChannel():New()
        oWebChannel:bJsToAdvpl := {|self,key,value| jsToAdvpl(self,key,value) } 
        oWebChannel:connect()
        
        // WebEngine (chromium embedded)
        oWebEngine := TWebEngine():New(oModal,0,0,100,100,/*cUrl*/,oWebChannel:nPort)
        oWebEngine:Align := CONTROL_ALIGN_ALLCLIENT
        
        // WebComponent de teste
        oTrackPed := TrackPed():Constructor()
        oWebEngine:navigate(;
            iif(oTrackPed:GetOS()=="UNIX", "file://", "")+;
            oTrackPed:mainHTML)
        
        // bLoadFinished sera disparado ao fim da carga da pagina
        // instanciando o bloco de codigo do componente, e tambem um customizado
        oWebEngine:bLoadFinished := {|webengine, url| oTrackPed:OnInit(webengine, url)}


    oModal:Activate()

return


// Funcao customizada que sera disparada apos o termino da carga da pagina
static function myLoadFinish(oWebEngine, url)
    conout("-> myLoadFinish(): Termino da carga da pagina")
    conout("-> Class: " + GetClassName(oWebEngine))
    conout("-> URL: " + url)
    conout("-> TempDir: " + oTrackPed::tmp)
   conout("-> Websocket port: " + cValToChar(oWebChannel:nPort))

    // Executa um runJavaScript
    oWebEngine:runJavaScript("alert('RunJavaScript: Termino da carga da pagina');")
return


// Blocos de codigo recebidos via JavaScript
static function jsToAdvpl(self,key,value)

    private aPedidoLocal    := {}
    private aOrdemLocal     := {}

	conout("",;
		"jsToAdvpl->key: " + key,;
           	"jsToAdvpl->value: " + value)

    // ---------------------------------------------------------------
    // Insira aqui o tratamento para as mensagens vindas do JavaScript
    // ---------------------------------------------------------------
    Do Case
        case key  == "<submit>" // [*Submit]

            if Len(value) = 6
                aadd( aPedidoLocal, StrTokArr(value, ",") )
                oTrackPed:set("aPedido", aPedidoLocal, {|| fSQLPedido()} )
            Else
                MsgStop("O Numero de Pedido precisa ter 6 digitos!", "Atencao")
            EndIf

            
        case key  == "<ordem>" // [ordem]

            aadd( aOrdemLocal, StrTokArr(value, ",") )
            oTrackPed:set("aOrdem", aOrdemLocal, {|| fSQLOrdem()} )

    EndCase
Return

//----------------------------------------------------------------
//Pesquisa no banco e guarda dados em variaveis.
// ---------------------------------------------------------------
static function fSQLPedido()
    local cPedidosDados     := ""
    local cPedido           := oTrackPed:get("aPedido")
    local aPedido           := AllTrim(cPedido[1][1])
    local x                 := 0
    private cDataEmiPed     := ""
    private cDataEntPed     := ""
    private cCodClient      := ""
    private cRazaoSocial    := ""
    private cNomeReduzi     := ""
    private cCNPJ           := ""
    private cLoja           := ""
    private aArrayOrdem     := {}

   
    //Consulta SC5 e pega Codigo do cliente e Data da emissão do pedido.
        BEGINSQL ALIAS "SQL_SC5"
        SELECT  C5_CLIENT,
                CONVERT(VARCHAR(10),CONVERT(DATE,C5_EMISSAO,103),103) AS C5_EMISSAO,
                C5_LOJACLI
            FROM %table:SC5% SC5
            WHERE  C5_NUM = %EXP:aPedido%
                AND C5_FILIAL = %xFilial:SC5%
                AND SC5.%notDel%
        ENDSQL

        //Se houve dados
        If ! SQL_SC5->(EoF())

            SQL_SC5->( dbGoTop() )

                cCodClient  := SQL_SC5->C5_CLIENT
                cDataEmiPed := SQL_SC5->C5_EMISSAO
                cLoja       := SQL_SC5->C5_LOJACLI

            SQL_SC5->( dbCloseArea() )

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

                Else

                    MsgStop("Nao foram encontrados registros!", "Atencao")
                    SQL_SA1->( dbCloseArea() )

                EndIf

            //Consulta SC6 e pega dados de entrega.
                BEGINSQL ALIAS "SQL_SC6"
                    SELECT  CONVERT(VARCHAR(10),CONVERT(DATE,C6_ENTREG,103),103) AS C6_ENTREG

                        FROM %table:SC6% SC6
                        WHERE  C6_NUM = %EXP:aPedido%
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

                    MsgStop("Nao foram encontrados registros da data de entrega!", "Atencao")
                    SQL_SC6->( dbCloseArea() )

                EndIf

            //Consulta SC2 e pega Numero da OP.
                BEGINSQL ALIAS "SQL_SC2"
                    SELECT  CONCAT(C2_NUM, C2_ITEM, C2_SEQUEN) AS C2_OP                
                        FROM %table:SC2% SC2
                        WHERE  C2_PEDIDO = %EXP:aPedido%
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

                    MsgStop("Nao foram encontrados registros de Orndem de Produção!", "Atencao")
                    SQL_SC2->( dbCloseArea() )

                EndIf

        Else

            MsgStop("Nao foram encontrados registros do pedido!", "Atencao")
            SQL_SC5->( dbCloseArea() )
            BREAK

        EndIf

    

     
    // Constroi HTML que será inserido na pagina com os dados.
        // Dados da SC5 e SC6
        cPedidosDados +=;
        "<div class='container'>"                                                                               +;
            "<h3>Dados do Pedido</h3>"                                                                          +;
            "<div class='row justify-content-center'>"                                                          +;
                "<div class='col-2'>"                                                                           +;
                    "<label for='pedido'>N° Pedido</label> "                                                    +;
                    "<input type='text' class='form-control' id='pedido' value='"+ aPedido +"' readonly>"       +;
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
        "</div>"

    // Dados da SA1
        cPedidosDados +=;
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
        "</div>"                                                                                                +;
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
                                    "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<ordem>`,`" + cOP + "`)'>IR</button>"+; // botão com o comando JavaScript para chamar a função fSQLOrdem()
                                "</div>"                                                                                                            +;
                            "</div>"
                    Next x

                        cPedidosDados +=;
                "</div>"                                                                                        +;
            "</div>"                                                                                            +;
        "</div>"

    
    oWebChannel:advplToJS("<track-pedido>", cPedidosDados)

return

static function fSQLOrdem()

    local cOrdemDados   := ""
    local aOrdem        := oTrackPed:get("aOrdem")
    local cOrdem        := AllTrim(aOrdem[1][1])
    local aOrdemMult    := {}
    local aPedido       := oTrackPed:get("aPedido")
    local cPedido       := AllTrim(aPedido[1][1])
    local aTempOper     := {}
    local x             := 0
    local y             := 0
    private cDataEmiPed     := ""
    private cDataEntPed     := ""
    private cCodClient      := ""
    private cRazaoSocial    := ""
    private cNomeReduzi     := ""
    private cCNPJ           := ""
    private cLoja           := ""
    private aArrayOrdem     := {}
    private cRoteiroOP      := {}
    
    //Consulta SC5 e pega Codigo do cliente e Data da emissão do pedido.
        BEGINSQL ALIAS "SQL_SC5"
        SELECT  C5_CLIENT,
                CONVERT(VARCHAR(10),CONVERT(DATE,C5_EMISSAO,103),103) AS C5_EMISSAO,
                C5_LOJACLI
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
                cLoja       := SQL_SC5->C5_LOJACLI

            SQL_SC5->( dbCloseArea() )

            
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

                Else

                    MsgStop("Nao foram encontrados registros!", "Atencao")
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

                        MsgStop("Nao foram encontrados registros!", "Atencao")
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

                    MsgStop("Nao foram encontrados registros!", "Atencao")
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

                    MsgStop("Nao foram encontrados registros!", "Atencao")
                    SQL_SC2->( dbCloseArea() )

                EndIf


            //Consulta SG2 e pega Número da Operação e descrição.
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

                            ctesteRoteDesc  :=  SQL_SG2->G2_OPERAC + "," +;
                                                SQL_SG2->G2_DESCRI

                            aadd( cRoteiroOP, StrTokArr(ctesteRoteDesc, ",") )

                            SQL_SG2->(DbSkip())

                        EndDo

                    SQL_SG2->( dbCloseArea() )

                Else

                    MsgStop("Nao foram encontrados dados de Logs de Procução!", "Atencao")
                    SQL_SG2->( dbCloseArea() )

                EndIf

            //Consulta SH6 e tras Tempo decorrido de cada operação e o Operador.
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

                            cTempOper  :=   SQL_SH6->H6_TEMPO + "," +;
                                            SQL_SH6->H6_OPERADO

                            aadd( aTempOper, StrTokArr(cTempOper, ",") )

                            SQL_SH6->(DbSkip())

                        EndDo

                    SQL_SH6->( dbCloseArea() )

                Else

                    MsgStop("Nao foram encontrados registros!", "Atencao")
                    SQL_SH6->( dbCloseArea() )

                EndIf

        Else

            MsgStop("Nao foram encontrados registros!", "Atencao")
            SQL_SC5->( dbCloseArea() )

        EndIf



    // Constroi HTML que será inserido na pagina com os dados.
        // Dados da SC5 e SC6
            cOrdemDados +=;
            "<div class='container'>"                                                                               +;
                "<h3>Dados do Pedido</h3>"                                                                          +;
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
        "</div>"                                                                                                +;
        "<div class='container'>"                                                                               +;
            "<div class='dropdown'>"                                                                            +;
                "<button class='dropbtn'>Ordens de Produção</button>"                                           +;
                "<div class='dropdown-content'>"                                                                +;
                    "<div class='input-group mb-3'>"
    //Alimenta o menu dropdown com os númenos das ops.
                    For x:=1 To Len(aArrayOrdem)
                        cOrdemDados +=;
                            "<div class='input-group mb-4'>"                                                    +;
                                "<input type='text' class='form-control' aria-describedby='basic-addon2' "      +;
                                " id='ordem' value='" + aArrayOrdem[x][1] + "' readonly>"                       +;
                                "<div class='input-group-append'>"                                              +;
                                    "<button class='btn btn-outline-secondary' "                                +;
                                    "onclick='twebchannel.jsToAdvpl(`<ordem>`,`" + aArrayOrdem[x][1] + "`)'>"   +; // botão com o comando JavaScript para chamar a função fSQLOrdem()
                                    "IR</button>"                                                               +;
                                "</div>"                                                                        +;
                            "</div>"
                    Next x
                        cOrdemDados +=;
                "</div>"                                                                                        +;
            "</div>"                                                                                            +;
        "</div>"

    // Constroi HTML que será inserido na pagina com os dados.
        // Dados da SC2 e SG2
            cOrdemDados +="<div class='container'>"                                                                                             +;
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
                            "</div>"                                                                                                            +;
                            "</br>"                                                                                                             +;
                                "<table class='table table-bordered table-striped table-dark'>"                                                 +;
                                        "<tr><td>Operação</td>"                                                                                 +;
                                            "<td>Descrição</td>"                                                                                +;
                                            "<td>Tempo</td>"                                                                                    +;
                                            "<td>Operador</td>"                                                                                 +;
                                            "</tr>"   //Fechamos o cabeçalho
                            If !Empty(cRoteiroOP)
                                For y:=1  To Len(cRoteiroOP)
                                cOrdemDados += "<tr><td>'"+ cRoteiroOP[y][1] +"'</td>"                                             +;
                                                    "<td>'"+ cRoteiroOP[y][2] +"'</td>"                                             +;
                                                    "<td>'"+ aTempOper[y][1] +"'</td>"                                              +;
                                                    "<td>'"+ aTempOper[y][2] +"'</td>"                                              +;
                                                "</tr>"
                                Next y
                            EndIf





    oWebChannel:advplToJS("<track-pedido>", cOrdemDados)

return


// Classe WebComponent de teste
class TrackPed 
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
Method Constructor() class TrackPed
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
Method OnInit(webengine, url) class TrackPed
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
Method Template() class TrackPed
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
                        <a class="navbar-brand">RASTREAMENTO PEDIDOS</a>
                        <form class="form-inline" id="trackFormPedido" name="pedido" onSubmit="return onClickSubmit(event, trackFormPedido);">
                            
                            <input class="form-control mr-sm-2" type="text" placeholder="Pedido" id="pedido" name="numero"> 
                            <button hidden class="btn btn-outline-success my-2 my-sm-0" id="btnSubmit" type="submit">PEDIDO</button>
                            
                        </form>
                    </div>
                    
                        
                                                                                               
                </nav>
            </div>
            <div id="track-Pedido"></div>
            
            <div id="track-Ordem"></div>
            
        <body>
    EndContent
return cHTML

// Scripts
Method Script() class TrackPed
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
Method Style() class TrackPed
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
Method Get(cVarname) class TrackPed
    // Recupera valor do array global (State)
    local nPosBase := AScan( ::mainData, {|x| x[1] == cVarname} )
    if nPosBase > 0
        return ::mainData[nPosBase, 2]
    endif
return ""

// Setter [*Getter_and_Setter]
Method Set(cVarname, xValue, bUpdate) class TrackPed
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
Method SaveFile(cContent) class TrackPed
    local nHdl := fCreate(iif(::GetOS()=="UNIX", "l:", "") + ::mainHTML)
    if nHdl > -1
        fWrite(nHdl, cContent)
        fClose(nHdl)
    else
        return .F.
    endif
return .T.

// Retorna Sistema Operacional em uso
Method GetOS() class TrackPed
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
