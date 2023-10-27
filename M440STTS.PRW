#include "protheus.ch"

/*{Protheus.doc} u_TrackPed()
    Funcao utilizada para inserir dados da Liberação Comercial na ZRP010.
    @author Rodrigo Augusto
    @since 08/08/2022
    @see: MTA450I() Documantation, TrackOrc()
    @observation: Compativel com SmartClient Desktop(Qt);
*/


user function M440STTS()
    
    Local aSUA 		:= SUA->(GetArea())
	Local aZRP 		:= ZRP->(GetArea())
    Local cDATETIME := DTOS(DATE()) + " " + cVALTOCHAR(TIME())
    Local cPedido   := SUA->UA_NUMSC5
    Local cStatus     := ""
    local cAlias    := "CRE_ZRP"
    private aMultLog	:= {}

    if xFilial("SUA") = "020101"
        dbSelectArea("SUA")
            SUA->(dbSetOrder(8))
            SUA->(dbSeek(xFilial("SUA") + cPedido))

                cOrcamento  := SUA->UA_NUM
                cVendedor   := SUA->UA_VEND
            
            
            //Consulta ZRP010 e pega os Logs de alreração de usuários do Orçamento.
                BEGINSQL ALIAS "CRE_ZRP"
                    SELECT  ZRP_STATUS
                        FROM %table:ZRP010% ZRP010 (NOLOCK) 
                                WHERE   R_E_C_N_O_ = (SELECT MAX(R_E_C_N_O_) 
                                                        FROM ZRP010 
                                                        WHERE ZRP_NUMERO = %EXP:cOrcamento% 
                                                        AND ZRP_FILIAL = %xFilial:ZRP%)
                                    
                                    //AND ZRP.%notDel%
                ENDSQL

                //Se houve dados
                If ! CRE_ZRP->(EoF())
    
                    cStatus := CRE_ZRP->ZRP_STATUS
                                        
                EndIf
            CRE_ZRP->( dbCloseArea() )

            If cStatus = "COM"
                cStatus := "CRE"
            ElseIf cStatus = "PED"
                cStatus := "CRE"
            ElseIf cStatus = "CRE"
                cStatus := "CRE"
            ElseIf cStatus = "PRD"
                cStatus := "CRD"

            Else
                cStatus := "CRP"
            EndIf

        dbSelectArea("SUA")
        SUA->(dbSetOrder(8))
        SUA->(dbSeek(xFilial("SUA") + cPedido))

        Begin Transaction

            RecLock("ZRP", .T.)
                Begin Transaction
                    ZRP->ZRP_FILIAL  	:= cFILANT
                    ZRP->ZRP_USER	 	:= cUSERNAME
                    ZRP->ZRP_USERID  	:= cVendedor
                    ZRP->ZRP_DATA	  	:= cDATETIME
                    ZRP->ZRP_NUMERO	  	:= cOrcamento
                    ZRP->ZRP_STATUS		:= cStatus
                End Transaction
            ZRP->(msUnlock())

        End Transaction

        // Altera o campo STATE da tabela ZRP e atualiza com a ultima atualização no estado do pedido/orçamento.
        aadd( aMultLog, StrTokArr(cOrcamento, ",") )
        u_UpdateZrp(aMultLog)

    EndIf
    If !Empty(Select( cAlias ))
        dbSelectArea ( cAlias )
        dbCloseArea ()
    Endif 

    RestArea(aSUA)
    RestArea(aZRP)

    


return
