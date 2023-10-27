#include "totvs.ch"

//Função babaca pra testar uma parada

User function UpdateZrp(aMultLog)

    if Len(aMultLog) = 0
        fCnsttZrp(aMultLog)
    EndIf

    fAltZRP(aMultLog)

Return

 //-------------------------------------------------//
Static function fCnsttZrp(aMultLog) //consulta ZRP inteira.
    private Orcamento     := ""
       

    //Consulta ZRP e pega numero do Orcamento.
        BEGINSQL ALIAS "SQL_ZRP1"
        				 
        SELECT DISTINCT 
            ZRP_NUMERO 
            FROM ZRP010 
                WHERE ZRP_FILIAL = %xFilial:ZRP%

        ENDSQL

        //Se houve dados
        If ! SQL_ZRP1->(EoF())

            SQL_ZRP1->( dbGoTop() )

                While ! SQL_ZRP1->(EoF())

                    Orcamento      := SQL_ZRP1->ZRP_NUMERO

                    aadd( aMultLog, StrTokArr(Orcamento, ",") )
            
                    SQL_ZRP1->(DbSkip())

                EndDo

            SQL_ZRP1->( dbCloseArea() )

        EndIf

        if 1=1
        Endif

Return(aMultLog)

//----------------------------------------------------------------------------------------//
static function fAltZRP(aMultLog) //Atualiza ZRP com a ultima modificação de status.

    Local Orc           := ""
    local NewOrc        := ""
    local NewOrcamento  := ""
    local y             := 0
    local x             := 0
    local aMultLogNew   := {}
    local Status        := ""


    //Enquanto houver dados
    If !Empty(aMultLog)

        For y:=1  To Len(aMultLog)

            Orc := AllTrim(aMultLog[y][1])

            BEGINSQL ALIAS "SQL_ZRP2"

            SELECT TOP 1 ZRP_NUMERO,
			             ZRP_STATUS 
                FROM ZRP010 
                    WHERE ZRP_NUMERO = %EXP:Orc%
                    AND ZRP_FILIAL = %xFilial:ZRP%
                    ORDER BY ZRP_DATA DESC
            
            ENDSQL

            //Se houve dados
            If ! SQL_ZRP2->(EoF())

                SQL_ZRP2->( dbGoTop() )

                    NewOrcamento      := SQL_ZRP2->ZRP_NUMERO + "," +;
                                        SQL_ZRP2->ZRP_STATUS

                    aadd( aMultLogNew, StrTokArr(NewOrcamento, ",") )
            
                SQL_ZRP2->( dbCloseArea() )

            EndIf

        Next y

    EndIf

    If !Empty(aMultLogNew)

        For x:=1  To Len(aMultLogNew)

            NewOrc  := AllTrim(aMultLogNew[x][1])
            Status  := AllTrim(aMultLogNew[x][2])

            Begin Transaction
               
                //Monta o Update
                cQryUpd := " UPDATE " + RetSqlName("ZRP") + " "
                cQryUpd += "     SET ZRP_STATE = '" + Status + "' "
                cQryUpd += " WHERE "
                cQryUpd += "     ZRP_FILIAL = '" + FWxFilial('ZRP') + "' "
                cQryUpd += "     AND ZRP_NUMERO = '" + NewOrc + "' "
                cQryUpd += "     AND D_E_L_E_T_ = ' ' "
            
                //Tenta executar o update
                nErro := TcSqlExec(cQryUpd)
                
                //Se houve erro, mostra a mensagem e cancela a transação
                If nErro != 0
                    MsgStop("Erro na execução da query: "+TcSqlError(), "Atenção")
                    DisarmTransaction()
                EndIf

            End Transaction

        Next x

    EndIf

return
