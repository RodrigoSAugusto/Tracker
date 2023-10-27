#INCLUDE "PROTHEUS.CH"
#INCLUDE "TBICONN.CH"

user function Trackemail(cHTML,cEmail)
  
  //Adicionar condicional para decidir se será enviado email do schedule ou u_trackorc.prw
  if !Empty(cHTML)

    fSendEmail(cHTML,cEmail)
  
  Else

    Prepare Environment EMPRESA "01" FILIAL "02"

      fPrepEmail()
      
    Reset Environment

  EndIf

return(NIL)


static function fPrepEmail()
  local x             := 0
  local aProjList     := {}
  local aCredList     := {}
  local cStatusCred   := "CRE"
  local cStatusCredp  := "CRP"
  local cStatusProj   := "PRJ"
  local cPedNumCred   := ""
  local cPedNumProj   := ""
  local cHTML         := ""
  local MvEmailProj   := GetMV("MV_EMAILPR")
  local MvEmailCred   := GetMV("MV_EMAILCR")

 
  //----------------------------------------------------------
  //Consulta ZRP010 e pega os Logs após Liberação Crédito.
  //----------------------------------------------------------
    BEGINSQL ALIAS "SQL_SUA"
        SELECT  DISTINCT 
                UA_NUMSC5,
                UA_NUM  
          FROM
                  %table:SUA010% SUA010 (NOLOCK)
                  INNER JOIN ZRP010 ON UA_FILIAL = ZRP_FILIAL AND UA_NUM = ZRP_NUMERO
          WHERE   
              ZRP_STATE IN (%EXP:cStatusCred%, %EXP:cStatusCredp%) 
          AND ZRP_FILIAL = %xFilial:ZRP%
              ORDER by UA_NUMSC5, UA_NUM
    ENDSQL

    //Se houve dados
      If ! SQL_SUA->(EoF())
        SQL_SUA->( dbGoTop() )
          While ! SQL_SUA->(EoF())

            cPedNumCred :=  SQL_SUA->UA_NUMSC5 + "," +;
                        SQL_SUA->UA_NUM

            aadd( aCredList, StrTokArr(cPedNumCred, ",") )

            SQL_SUA->(DbSkip())
          EndDo
        SQL_SUA->( dbCloseArea() )
      Else
        SQL_SUA->( dbCloseArea() )
      EndIf    

  //Se aCredList não estiver vazia, consulta a SUA e pega o número dos pedidos e monta um array
    If !empty(aCredList)

      cEmail := MvEmailCred

      cHTML :=  "<!DOCTYPE html>"+;
                  "<html lang='en'>"+;
                      "<body>"+;
                          "<h3>Lista de Pedidos Aguardando Liberação de Crédito:</h3>"+;
                          "<table cellspacing='0' cellpadding='10' border='2'>"+;
                              "<tr>"+;
                                  "<td width='120'>N° do Pedido</td>"+;
                                  "<td width='120'>N° do Orçamento</td>"+;
                              "</tr>"
      //Preenche a tabela com a lista de Pedidos em Aberto.
      for x:=1 to Len(aCredList)
        cHTML += ;
                    "<tr>"+;
                        "<td width='120'>"+ cValToChar(aCredList[x][1]) +"</td>"+;
                        "<td width='120'>"+ cValToChar(aCredList[x][2]) +"</td>"+;
                    "</tr>"
      next x
      cHTML += ;
                  "</table>"+;
              "</body>"+;
          "</html>"

      fSendEmail(cHTML,cEmail)

    EndIf
  //----------------------------------------------------------
  //Consulta ZRP010 e pega os Logs após Liberação de Projeto.
  //----------------------------------------------------------
    BEGINSQL ALIAS "SQL_SUA"
        SELECT  DISTINCT 
                UA_NUMSC5,
                UA_NUM   
          FROM
                %table:SUA010% SUA010 (NOLOCK)
                INNER JOIN ZRP010 ON UA_FILIAL = ZRP_FILIAL AND UA_NUM = ZRP_NUMERO
          WHERE   
              ZRP_STATE = %EXP:cStatusProj%
          AND ZRP_FILIAL = %xFilial:ZRP%
              ORDER by UA_NUMSC5, UA_NUM
    ENDSQL

    //Se houve dados
    If ! SQL_SUA->(EoF())
      SQL_SUA->( dbGoTop() )
        While ! SQL_SUA->(EoF())

          cPedNumProj :=  SQL_SUA->UA_NUMSC5 + "," +;
                      SQL_SUA->UA_NUM

          aadd( aProjList, StrTokArr(cPedNumProj, ",") )

          SQL_SUA->(DbSkip())
        EndDo
      SQL_SUA->( dbCloseArea() )
    Else
        SQL_SUA->( dbCloseArea() )
    EndIf    

  //Se aProjList não estiver vazia, consulta a SUA e pega o número dos pedidos e monta um array
    If !empty(aProjList)
      cEmail := MvEmailProj

      cHTML :=  "<!DOCTYPE html>"+;
                  "<html lang='en'>"+;
                      "<body>"+;
                          "<h3>Lista de Pedidos Aguardando Liberação de Projeto:</h3>"+;
                          "<table cellspacing='0' cellpadding='10' border='2'>"+;
                              "<tr>"+;
                                  "<td width='120'>N° do Pedido</td>"+;
                                  "<td width='120'>N° do Orçamento</td>"+;
                              "</tr>"

      for x:=1 to Len(aProjList) //Preenche a tabela com a lista de Pedidos em Aberto.
        cHTML += ;
                    "<tr>"+;
                        "<td width='120'>"+ cValToChar(aProjList[x][1]) +"</td>"+;
                        "<td width='120'>"+ cValToChar(aProjList[x][2]) +"</td>"+;
                    "</tr>"
      next x
      cHTML += ;
                  "</table>"+;
              "</body>"+;
          "</html>"

      fSendEmail(cHTML,cEmail)

    EndIf

return


//---------------------------------------------------------------------------------------
//Função para realizar os disparos de email.
//---------------------------------------------------------------------------------------
static function fSendEmail(cHTML,cEmail)
  Local cUser := "", cPass := "", cSendSrv := ""
  Local cMsg := ""
  Local nSendPort := 0, nSendSec := 0, nTimeout := 0
  Local xRet
  Local oServer, oMessage


  cUser := "pedidos.pendentes@processoindustrial.com.br" //define the e-mail account username
  cPass := "hjn&prck3rt" //define the e-mail account password
  cSendSrv := "smtp.tegape.com.br" // define the send server
  nTimeout := 60 // define the timout to 60 seconds
   
  oServer := TMailManager():New()
   
  oServer:SetUseSSL( .F. )
  oServer:SetUseTLS( .F. )

  if nSendSec == 0
    nSendPort := 25 //default port for SMTP protocol
  elseif nSendSec == 1
    nSendPort := 465 //default port for SMTP protocol with SSL
    oServer:SetUseSSL( .T. )
  else
    nSendPort := 587 //default port for SMTPS protocol with TLS
    oServer:SetUseTLS( .T. )
  endif

  // once it will only send messages, the receiver server will be passed as ""
  // and the receive port number won't be passed, once it is optional
  xRet := oServer:Init( "", cSendSrv, cUser, cPass, , nSendPort )
  if xRet != 0
    cMsg := "Could not initialize SMTP server: " + oServer:GetErrorString( xRet )
    FWLogMsg("ERROR", /*cTransactionId*/, /*cGroup*/, /*cCategory*/, /*cStep*/, /*cMsgId*/, cMsg  , /*nMensure*/, /*nElapseTime*/, /*aMessage*/)
    return
  endif

  // the method set the timout for the SMTP server
  xRet := oServer:SetSMTPTimeout( nTimeout )
  if xRet != 0
    cMsg := "Could not set " + cProtocol + " timeout to " + cValToChar( nTimeout )
    FWLogMsg("ERROR", /*cTransactionId*/, /*cGroup*/, /*cCategory*/, /*cStep*/, /*cMsgId*/, cMsg  , /*nMensure*/, /*nElapseTime*/, /*aMessage*/)
  endif

  // estabilish the connection with the SMTP server
  xRet := oServer:SMTPConnect()
  if xRet <> 0
    cMsg := "Could not connect on SMTP server: " + oServer:GetErrorString( xRet )
    FWLogMsg("ERROR", /*cTransactionId*/, /*cGroup*/, /*cCategory*/, /*cStep*/, /*cMsgId*/, cMsg  , /*nMensure*/, /*nElapseTime*/, /*aMessage*/)
    return
  endif

  // authenticate on the SMTP server (if needed)
  xRet := oServer:SmtpAuth( cUser, cPass )
  if xRet <> 0
    cMsg := "Could not authenticate on SMTP server: " + oServer:GetErrorString( xRet )
    FWLogMsg("ERROR", /*cTransactionId*/, /*cGroup*/, /*cCategory*/, /*cStep*/, /*cMsgId*/, cMsg  , /*nMensure*/, /*nElapseTime*/, /*aMessage*/)
    oServer:SMTPDisconnect()
    return
  endif

  oMessage := TMailMessage():New()
  oMessage:Clear()

  oMessage:cDate := cValToChar( Date() )
  oMessage:cFrom := "pedidos.pendentes@processoindustrial.com.br"
  oMessage:cTo := cEmail
  oMessage:cSubject := "Rastreador"
  oMessage:cBody := cHTML

  xRet := oMessage:Send( oServer )
  if xRet <> 0
    cMsg := "Could not send message: " + oServer:GetErrorString( xRet )
    FWLogMsg("ERROR", /*cTransactionId*/, /*cGroup*/, /*cCategory*/, /*cStep*/, /*cMsgId*/, cMsg  , /*nMensure*/, /*nElapseTime*/, /*aMessage*/)
  endif

  xRet := oServer:SMTPDisconnect()
  if xRet <> 0
    cMsg := "Could not disconnect from SMTP server: " + oServer:GetErrorString( xRet )
    FWLogMsg("ERROR", /*cTransactionId*/, /*cGroup*/, /*cCategory*/, /*cStep*/, /*cMsgId*/, cMsg  , /*nMensure*/, /*nElapseTime*/, /*aMessage*/)
  endif
return

