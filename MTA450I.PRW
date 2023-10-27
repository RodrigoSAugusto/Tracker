#include "protheus.ch"

 
/*{Protheus.doc} u_TrackPed()
    Funcao utilizada para inserir dados na ZRP para o rastreador de Pedidos/Orçamentos, na liberação de Crédito.
    @author Rodrigo Augusto
    @since 08/08/2022
    @see: MTA450I() Documantation, TrackOrc()
    @observation: Compativel com SmartClient Desktop(Qt);
*/


User Function MTA450I()

    Local aSUA 		:= SUA->(GetArea())
	Local aSC9 		:= SC9->(GetArea())
	Local aZRP 		:= ZRP->(GetArea())
    Local cPedido   := C9_PEDIDO
    Local cStatus	:= ""
	Local cDATETIME := DTOS(DATE()) + " " + cVALTOCHAR(TIME())
    local cDate     := DTOS(DATE())
    private aMultLog	:= {}

    //Verifica a filial e altera a ZRP010 de acordo com as liberações de crédito.
        if xFilial("SUA") = "020101"    
            dbSelectArea("SUA")
            SUA->(dbSetOrder(8))
            SUA->(dbSeek(xFilial("SUA") + cPedido))

                cOrcamento  := SUA->UA_NUM
                cVendedor   := SUA->UA_VEND      
            
            //Consulta ZRP010 e pega os Logs de alreração de usuários do Orçamento.
                BEGINSQL ALIAS "SQL_ZRP"
                    SELECT  ZRP_STATUS
                        FROM
                                %table:ZRP010% ZRP010 (NOLOCK) 
                                WHERE   R_E_C_N_O_ = (SELECT MAX(R_E_C_N_O_) 
                                                        FROM ZRP010 
                                                        WHERE ZRP_NUMERO = %EXP:cOrcamento% 
                                                        AND ZRP_FILIAL = %xFilial:ZRP%)
                                                        //AND ZRP.%notDel%
                ENDSQL

                //Se houve dados
                If ! SQL_ZRP->(EoF())
    
                    cStatus := SQL_ZRP->ZRP_STATUS
                    
                EndIf
            
            SQL_ZRP->( dbCloseArea() )

            //Altera o status da ZRP conforme a operação de liberação de crédito.
            If cStatus = "CRE"
                cStatus := "ENG"
            ElseIf cStatus = "PED"
                cStatus := "ENG"
            ElseIf cStatus = "COM"
                cStatus := "ENG"
            ElseIf cStatus = "PRD"
                cStatus := "ENG"
            Else
                cStatus := "PRJ"
            EndIf

            dbSelectArea("SC9")
            SC9->(dbSetOrder(1))
            SC9->(dbSeek(xFilial("SC9") + C9_PEDIDO))

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

            dbCloseArea()
            // Altera o campo STATE da tabela ZRP e atualiza com a ultima atualização no estado do pedido/orçamento.
            aadd( aMultLog, StrTokArr(cOrcamento, ",") )
            u_UpdateZrp(aMultLog)

        EndIf

    //------------------------------------------------------------------------------------------------------------------------
    //Preenche o Campo C9_XLIBCRE da SC9010 para marcar a data de liberação, esta data é usada no relatório TCOB01.PRW
    //------------------------------------------------------------------------------------------------------------------------

    dbSelectArea("SC9")
    SC9->(dbSetOrder(1))
    SC9->(dbSeek(xFilial("SC9") + C9_PEDIDO))
    
        RecLock("SC9", .F.)

            Begin Transaction
                SC9->C9_XLIBCRE     := cDate
                SC9->C9_XUSER       := cUSERNAME
            End Transaction

        SC9->(msUnlock())

    dbCloseArea()

    RestArea(aSUA)
    RestArea(aSC9)
    RestArea(aZRP)

Return
