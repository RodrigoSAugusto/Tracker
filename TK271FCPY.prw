#INCLUDE "Protheus.ch"   

/*/{Protheus.doc} User Function TK271FCPY
    Esse ponto de entrada é executado ao fim da gravação de cópia de atendimento do Televendas.
    @type  Function
    @author Rodrigo Augusto
    @since 20/06/2023
    @version 1.0
    @example
    (examples)
    @see (links_or_references)
/*/

User Function TK271FCPY()

    If cFILANT = "020101"
        ZRPAtualiz()
    EndIf
Return 

Static Function ZRPAtualiz()

    Local aSC5 			:= SC5->(GetArea())
    Local aSUA 			:= SUA->(GetArea())
    Local aZRP 			:= ZRP->(GetArea())
    Local cCodVendZRP   := ''
    Local aMultLog      := {}

    dbSelectArea("SUA")
    SUA->(dbSetOrder(1))
    SUA->(dbSeek(xFilial("SUA") + SUA->UA_NUM))
    cNumSC5     := SUA->UA_NUMSC5
    cNumSUA     := SUA->UA_NUM

    If Select("SUA") > 0
        dbSelectArea("SUA")
        dbCloseArea()
    EndIf

    
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

    RestArea(aZRP)
    RestArea(aSUA)
    RestArea(aSC5)


Return
