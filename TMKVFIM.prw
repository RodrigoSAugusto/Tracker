#include "protheus.ch"

/*{Protheus.doc} u_TrackPed()
    Funcao utilizada para inserir dados na ZRP para o rastreador de Pedidos/Orçamentos.
    @author Rodrigo Augusto
    @since 08/08/2022
    @see: MTA450I() Documantation, TrackOrc()
    @observation: Compativel com SmartClient Desktop(Qt);
*/


User Function TMKVFIM(cNumSUA, cNumSC5)
	Local aBkp 			:= GetArea()
	Local aSC5 			:= SC5->(GetArea())
	Local aSC6 			:= SC6->(GetArea())
	Local aSUA 			:= SUA->(GetArea())
	Local aSUB 			:= SUB->(GetArea())
	Local aZRP 			:= ZRP->(GetArea())
	local cCodVendZRP	:= ""
	private aMultLog	:= {}
	//Local cQry  := ""

	If !Empty(cNumSC5) .and. (SC5->C5_NUM # cNumSC5) // Operador # é obsoleto indeca uma comparação igual a <> ou != (diferente)
		dbSelectArea("SC5")
		SC5->(dbSetOrder(1))
		SC5->(dbSeek(xFilial("SC5") + cNumSC5))
	EndIf

	If cFILANT = "020101"
		If !Empty(cNumSC5)// Insere alterações de usuários na ZRP e adiciona com a identificação PED ou ORC.

			//Alerta perguntando se o pedido precisa de projeto ou não e seta a variavel cTipo de acordo com a resposta do Usuário.
				If FWAlertYesNo( 'Este pedido precisa de projeto?', 'Pedidos para Projeto' )
					cTipo	:= "COP"
				Else
					cTipo	:= "COM" // Retirada mensagem de confirmação 09/09/2022
				Endif
		Else 
			//Adiciona registro com identificação ORC.
				cTipo		:= "ORC"

		EndIf

		//Define data e hora ha serem inseridos na ZRP
			cDATETIME 	:= DTOS(DATE()) + " " + cVALTOCHAR(TIME())

		//Pega o codigo e nome do vendendos e popula as variáveis
			BEGINSQL ALIAS "SQL_SU7"
			SELECT	U7_CODVEN,
					U7_NREDUZ
					FROM SU7010
						LEFT OUTER JOIN SUA010 ON UA_OPERADO = U7_COD AND UA_FILIAL = U7_FILIAL
							WHERE UA_NUM = %EXP:cNumSUA%
							AND UA_FILIAL = %EXP:cFILANT%
			ENDSQL


		//Se houve dados
			If ! SQL_SU7->(EoF())

				SQL_SU7->( dbGoTop() )

					cCodVendedor    := SQL_SU7->U7_CODVEN
					cNomeVendedor	:= Alltrim(SQL_SU7->U7_NREDUZ)

				SQL_SU7->( dbCloseArea() )

			EndIf

			If Select("SQL_SU7") > 0
				dbSelectArea("SQL_SU7")
				dbCloseArea()
			EndIf

		//Pega dados da ZRP e compara com os atuais.
			BEGINSQL ALIAS "SQL_ZRP"
				SELECT TOP 1 ZRP_USERID fROM ZRP010
						WHERE ZRP_NUMERO = %EXP:cNumSUA%
						AND ZRP_FILIAL = %EXP:cFILANT%
						ORDER BY ZRP_DATA DESC
			ENDSQL

			//Se houve dados
				If ! SQL_ZRP->(EoF())

					SQL_ZRP->( dbGoTop() )

						cCodVendZRP    := SQL_ZRP->ZRP_USERID

					SQL_ZRP->( dbCloseArea() )

				EndIf

				If Select("SQL_ZRP") > 0
					dbSelectArea("SQL_ZRP")
					dbCloseArea()
				EndIf
			
			//Compara ZRP com SUA, se o código for diferênte atualiza a ZRP.
			If cCodVendZRP <> cCodVendedor
			
				RecLock("ZRP", .T.)
					Begin Transaction
						ZRP->ZRP_FILIAL  	:= cFILANT
						ZRP->ZRP_USER	 	:= cNomeVendedor
						ZRP->ZRP_USERID  	:= cCodVendedor
						ZRP->ZRP_DATA	  	:= cDATETIME
						ZRP->ZRP_NUMERO	  	:= cNumSUA
						ZRP->ZRP_STATUS		:= cTipo
					End Transaction
				ZRP->(msUnlock())

				// Altera o campo STATE da tabela ZRP e atualiza com a ultima atualização no estado do pedido/orçamento.
				aadd( aMultLog, StrTokArr(cNumSUA, ",") )
				u_UpdateZrp(aMultLog)

			EndIf
	EndIf

		


// FIM DAS ALTERAÇÕES PARA O RASTREADOR DE PEDIDOS.

		If !Empty(cNumSC5) .and. (SC5->C5_NUM # cNumSC5)
			dbSelectArea("SC5")
			SC5->(dbSetOrder(1))
			SC5->(dbSeek(xFilial("SC5") + cNumSC5))
		EndIf

	If !Empty(cNumSC5) .and. (SC5->C5_NUM == cNumSC5)
		dbSelectArea("SUB")
		SUB->(dbSetOrder(1))
		SUB->(dbSeek(xFilial("SUB") + cNumSUA))
		While !Eof() .and. (SUB->UB_FILIAL + SUB->UB_NUM == xFilial("SUA") + cNumSUA)
			dbSelectArea("SC6")
			SC6->(dbSetOrder(1))
			If SC6->(dbSeek(xFilial("SC6") + cNumSC5 + SUB->UB_ITEMPV))
				RecLock("SC6", .F.)
				Begin Transaction
					SC6->C6_XOBS  	:= SUB->UB_XOBS
					SC6->C6_DESCRI 	:= SUB->UB_XDESNFE
					//SC6->C6_XDESNFE	:= SUB->UB_XDESNFE //ALTERADO PARA COLOCAR A DESCRICAO PADRAO NO CAMPO CUSTOMIZADO A PEDIDO DA ANDREIA TQ 26/01/2022
					SC6->C6_XDESNFE	:= POSICIONE('SB1',1,xFilial('SB1')+SUB->UB_PRODUTO,'B1_DESC')
					SC6->C6_ITEMPC	:= SUB->UB_ITEMPC
					SC6->C6_NUMPCOM	:= SUB->UB_NUMPCOM
					SC6->C6_PEDCLI  := SUB->UB_NUMPCOM // solicitado por Elaine em 22/01/2020
					SC6->C6_MOPC  	:= SUB->UB_XMOPC //
					
				End Transaction
				SC6->(msUnlock())
			EndIf
			SUB->(dbSkip())
		EndDo
		RecLock("SC5", .F.)
			SC5->C5_MENNOTA := SUA->UA_XMENNOT
			SC5->C5_NATUREZ := SUA->UA_XNATURE
			SC5->C5_XOBSORC := SUA->UA_XOBSORC
			SC5->C5_XEMAIL  := SUA->UA_XEMAIL
			SC5->C5_XOBS    := MSMM(SUA->UA_CODOBS)
			SC5->C5_REDESP  := SUA->UA_XREDESP
			SC5->C5_XPRAZO  := SUA->UA_XPRAZO
			SC5->C5_XOBSCLI := SUA->UA_XOBSCLI
			SC5->C5_VEND2 	:= SUA->UA_XVEND2  //INCLUIDO 29/04/21
			SC5->C5_TRANSP 	:= SUA->UA_TRANSP //INCLUIDO 13/05/21
		msUnlock()		
	EndIf

	RestArea(aSUB)
	RestArea(aSUA)
	RestArea(aSC6)
	RestArea(aSC5)
	RestArea(aBkp)
	RestArea(aZRP)

Return
