************************************************************************
* Developer        : Mehmet Dağnilak
* Description      : Programı RFC aracılığıyla kopyala
************************************************************************
* History
*----------------------------------------------------------------------*
* User-ID     Date      Description
*----------------------------------------------------------------------*
* MDAGNILAK   20200722  Program created
* <userid>    yyyymmdd  <short description of the change>
************************************************************************

report zdagnilak_copy_program_rfc.

tables: sscrfields.

selection-screen begin of block b1 with frame.
parameters: program  radiobutton group prg,
            p_prog   type syrepid memory id zcopy_name,
            p_notext as checkbox default 'X'.
selection-screen skip.
parameters: function radiobutton group prg,
            p_func   type tfdir-funcname memory id zcopy_func.
selection-screen skip.
parameters: method   radiobutton group prg,
            p_class  type seoclsname memory id zcopy_class,
            p_method type seocpdname memory id zcopy_method.
selection-screen end of block b1.

selection-screen begin of block b2 with frame.
parameters: p_destin type rfcdest obligatory memory id vers_dest.
selection-screen end of block b2.

data: gv_debug type i.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN
*&---------------------------------------------------------------------*
at selection-screen.
  if sscrfields-ucomm eq 'DEBUG'.
    gv_debug = 1 - gv_debug.
    message |Debug mode { gv_debug }| type 'S'.
    clear sscrfields-ucomm.
  endif.

  "RFC hedefinin yalnızca bir kere şifre sorması için çalıştırma burada yapıldı.
  if sscrfields-ucomm eq 'ONLI'.
    perform main.
    clear sscrfields-ucomm.
  endif.

start-of-selection.
  "nothing

*&---------------------------------------------------------------------*
*&      Form  main
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form main.

  data: lo_reader      type ref to if_siw_repository_reader,
        lt_code        type siw_tab_code,
        lt_textpool    type textpool_table,
        lv_incname     type syrepid,
        lv_description type repti,
        ls_exception   type siw_str_msg,
        lv_msg         type text255.

  lo_reader = cl_siw_resource_access=>s_get_instance( ).

  try.

      case abap_true.
        when program.
          data(ls_trdir) = lo_reader->read_trdir( p_prog ).
          if ls_trdir is initial.
            message 'Program mevcut değil' type 'I'.
            return.
          endif.

          lv_incname = p_prog.
          lt_code = lo_reader->read_report( p_prog ).

          if ls_trdir-subc ca '1MFS'.
            data(lt_textall) = lo_reader->read_textpool( i_prog      = p_prog
                                                         i_tab_langu = value #( ( spras = sy-langu ) ) ).

            lt_textpool = value #( lt_textall[ 1 ]-texts optional ).
            lv_description = value #( lt_textpool[ id = 'R' ]-entry optional ).

            if p_notext eq abap_true.
              refresh lt_textpool.
            endif.
          endif.

        when function.
          data(ls_funcinfo) = lo_reader->read_funcinfo( p_func ).
          lv_incname = ls_funcinfo-include.
          ls_trdir-subc = 'I'.
          lt_code = lo_reader->read_report( lv_incname ).

        when method.
          lo_reader->read_method_source(
            exporting
              i_clsname    = p_class
              i_methodname = p_method
            importing
              e_tab_code   = lt_code
              e_incname    = lv_incname ).

      endcase.

    catch cx_siw_resource_failure into data(lx_rf).
      message lx_rf type 'I' display like 'E'.
      return.
  endtry.


  if gv_debug = 1.
    break-point.
  endif.

  case abap_true.
    when program
      or function.

      call function 'SIW_RFC_WRITE_REPORT'
        destination p_destin
        exporting
          i_name                = lv_incname
          i_tab_code            = lt_code
          i_extension           = ''
          i_object              = ''
          i_objname             = ''
          i_progtype            = ls_trdir-subc
          i_description         = lv_description
        importing
          e_str_exception       = ls_exception
        exceptions
          system_failure        = 1 message lv_msg
          communication_failure = 2 message lv_msg.

    when method.
      call function 'SIW_RFC_WRITE_CLASS_METHOD'
        destination p_destin
        exporting
          i_clsname             = p_class
          i_methodname          = p_method
          i_tab_code            = lt_code
        importing
          e_str_exception       = ls_exception
        exceptions
          system_failure        = 1 message lv_msg
          communication_failure = 2 message lv_msg.

  endcase.

  if sy-subrc ne 0 or
     lv_msg is not initial.
    message lv_msg type 'I' display like 'E'.
    return.
  endif.

  if ls_exception is not initial.
    message ls_exception-msgstring type 'I' display like 'E'.
    return.
  endif.

  if lt_textpool is not initial.

    if gv_debug = 1.
      break-point.
    endif.

    call function 'SIW_RFC_WRITE_TEXTPOOL'
      destination p_destin
      exporting
        i_prog                = lv_incname
        i_langu               = sy-langu
        i_tab_textpool        = lt_textpool
      importing
        e_str_exception       = ls_exception
      exceptions
        system_failure        = 1 message lv_msg
        communication_failure = 2 message lv_msg.

    if sy-subrc ne 0 or
       lv_msg is not initial.
      message lv_msg type 'I' display like 'E'.
      return.
    endif.

    if ls_exception is not initial.
      message ls_exception-msgstring type 'I' display like 'E'.
      return.
    endif.

  endif.

  message |Program { lv_incname } kopyalandı| type 'S'.

endform.          " main
