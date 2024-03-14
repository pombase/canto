"use strict";

/*global $,document,application_root,window,curs_root_uri,curs_people_autocomplete_list */

// eslint-disable-next-line no-unused-vars
function trim(a) {
  a=a.replace(/^\s+/,''); return a.replace(/\s+$/,'');
}

function removeIf(arr, callback) {
    var i = arr.length;
    while (i--) {
        if (callback(arr[i], i)) {
            arr.splice(i, 1);
        }
    }
}

var loadingDiv = $('<div id="loading" style="z-index: 2000;"><img src="' + application_root +
                   '/static/images/spinner.gif"/></div>');

function loadingStart() {
  loadingDiv.show();
  $('#ajax-loading-overlay').show();
}

function loadingEnd() {
  loadingDiv.hide();
  $('#ajax-loading-overlay').hide();
}

$(document).ready(function() {
  loadingDiv
    .prependTo('body')
    .position({
      my: 'center',
      at: 'center',
      of: $('#content'),
      offset: '0 200'
    })
    .hide()  // hide it initially
    .bind('ajaxStart.canto', loadingStart)
    .bind('ajaxStop.canto', loadingEnd);
});

$(document).ready(function() {
  $(".sect .undisclosed-title, .sect .disclosed-title").each(function() {
    $(this).click(function() {
      $(this).next().toggle();
      $(this).toggleClass('undisclosed-title');
      $(this).toggleClass('disclosed-title');
      return false;
    });
    if ($(this).is(".undisclosed-title")) {
      $(this).next().hide();
    } else {
      $(this).next().show();
    }
  });
});

// eslint-disable-next-line no-unused-vars
function make_ontology_complete_url(annotation_type, extensionLookup) {
  var url = application_root + '/ws/lookup/ontology/' + annotation_type + '?def=1';
  if (extensionLookup) {
    url += '&extension_lookup=' + extensionLookup;
  }
  return url;
}

function make_confirm_dialog(link, prompt, confirm_button_label, cancel_button_label) {
  var targetUrl = link.attr("href");

  var confirmDialog = $('#confirm-dialog');
  if (confirmDialog.length == 0) {
    confirmDialog =
      $('<div id="confirm-dialog" title="Confirmation needed">' + prompt + '</div>');
    $('body').append(confirmDialog);
  }

  confirmDialog.dialog({
    autoOpen: false,
    modal: true,
    buttons : [
      {
        text: cancel_button_label,
        click: function() {
          $(this).dialog("close");
          $(this).remove();
        }
      },
      {
        text: confirm_button_label,
        click: function() {
          window.location.href = targetUrl;
        }
      }
    ]
  });

  confirmDialog.dialog("open");
}

// eslint-disable-next-line no-unused-vars
var ferret_choose = {
  show_autocomplete_def: function(event, ui) {
    $('.curs-autocomplete-definition').remove();
    var definition;
    if (ui.item.definition == null) {
      definition = '[no definition]';
    } else {
      definition = ui.item.definition;
    }
    var def =
      $('<div class="curs-autocomplete-definition ui-widget-content ui-autocomplete ui-corner-all">' +
        '<h3>Term name</h3><div>' +
        ui.item.name + '</div>' +
        '<h3>Definition</h3><div>' +
        definition + '</div></div>');
    def.appendTo('body');
    var widget = $(this).autocomplete("widget");
    def.position({
      my: 'left top',
      at: 'right top',
      of: widget
    });
    return false;
  },

  hide_autocomplete_def: function() {
    $('.curs-autocomplete-definition').remove();
  }
};


$(document).ready(function() {
  $('a.canto-select-all').click(function () {
    $(this).closest('div').find('input:checkbox').attr('checked', true);
  });

  $('a.canto-select-none').click(function () {
    $(this).closest('div').find('input:checkbox').removeAttr('checked');
  });

  $('#curs-finish-session').click(function () {
    window.location.href = curs_root_uri + '/finish_form';
  });

  $('.curs-pause-session').click(function () {
    window.location.href = curs_root_uri + '/pause_curation';
  });

  $('#curs-reassign-session').click(function () {
    window.location.href = curs_root_uri + '/reassign_session';
  });

  $('.curs-assign').click(function () {
    window.location.href = curs_root_uri + '/assign_session';
  });

  $('.curs-reassign').click(function () {
    window.location.href = curs_root_uri + '/reassign_session';
  });

  $('#curs-check-completed').click(function () {
    window.location.href = curs_root_uri + '/complete_approval';
  });

  $('#curs-cancel-approval').click(function () {
    window.location.href = curs_root_uri + '/cancel_approval';
  });

  $('#curs-stop-reviewing').click(function () {
    window.location.href = curs_root_uri + '/';
  });

  $('#curs-pub-assign-popup-dialog').click(function () {
    $('#curs-pub-assign-dialog').dialog({ modal: true,
                                          title: 'Set the corresponding author...',
                                          width: '40em' });
  });

  $('#curs-pub-create-session-popup-dialog').click(function () {
    $('#curs-pub-create-session-dialog').dialog({ modal: true,
                                                  title: 'Create a session',
                                                  width: '40em' });
  });

  $('#curs-pub-reassign-session-popup-dialog').click(function () {
    $('#curs-pub-reassign-session-dialog').dialog({ modal: true,
                                                    title: 'Reassign a session',
                                                    width: '40em' });
  });

  $('#curs-pub-triage-this-pub').click(function () {
    window.location.href = application_root + '/tools/triage?triage-return-pub-id=' + $(this).val();
  });

  $('#curs-pub-assign-cancel,#curs-pub-create-session-cancel,.curs-dialog-cancel').click(function () {
    $(this).closest('.ui-dialog-content').dialog('close');
    return false;
  });

  function person_picker_add_person(current_this, initial_name) {
    var $popup = $('#person-picker-popup');
    $popup.find('.curs-person-picker-add-name').val(initial_name);
    var $picker_div = $(current_this).closest('div');
    $popup.data('success_callback', function(data) {
      $picker_div.find('.curs-person-picker-input').val(data.name);
      $picker_div.find('.curs-person-picker-person-id').val(data.person_id);
    });
    $popup.dialog({
      title: 'Add a person...',
      modal: true });

    $popup.find("form").ajaxForm({
      success: function(data) {
        if (typeof(data.error_message) == 'undefined') {
          ($popup.data('success_callback'))(data);
          $popup.dialog( "close" );
        } else {
          $.pnotify({
            pnotify_title: 'Error',
            pnotify_text: data.error_message,
          });
        }
      },
      dataType: 'json'
    });
  }

  $('#curs-pub-assign-submit,#curs-pub-create-session-submit').click(function () {
    var $dialog = $(this).closest('.ui-dialog-content');
    // if the user types a name that doesn't autocomplete show the new person dialog
    if ($dialog.find('.curs-person-picker-person-id').val().length == 0) {
      var new_person_name = $dialog.find('.curs-person-picker-input').val();
      person_picker_add_person(this, new_person_name);
      return false;
    }

    $dialog.dialog('close');
    return true;
  });

  function truncate($element) {
    $element.each(function() {
      var obj = $(this);
      var body = obj.html();

      if (body.length > 320) {
	var splitLoc = body.indexOf(' ', 300);
	if (splitLoc != -1) {
	  var splitLocation = body.indexOf(' ', 300);
	  var str1 = body.substring(0, splitLocation);
	  var str2 = body.substring(splitLocation, body.length - 1);
	  obj.html(str1 + '<span class="truncate_ellipsis">...</span> <span class="truncate_more">' + str2 + '</span>');
	  obj.find('.truncate_more').css("display", "none");
	  obj.append(
	    '<div class="clearboth">' +
	      '<a href="#" class="truncate_more_link">more</a>' +
	      '</div>'
	  );

	  var moreLink = $('.truncate_more_link', obj);
	  var moreContent = $('.truncate_more', obj);
	  var ellipsis = $('.truncate_ellipsis', obj);
	  moreLink.click(function() {
	    moreContent.show();
	    moreLink.remove();
	    ellipsis.remove();
	  });
	}
      }
    });
  }

  truncate($('.non-key-attribute'));

  if (typeof curs_people_autocomplete_list != 'undefined') {
    $(".curs-person-picker .curs-person-picker-input").autocomplete({
      minLength: 0,
      source: curs_people_autocomplete_list,
      focus: function( event, ui ) {
        $(this).val( ui.item.name );
        return false;
      },
      select: function( event, ui ) {
        $(this).val( ui.item.name );
        $(this).siblings('.curs-person-picker-person-id').val( ui.item.value );
        return false;
      }
    })
    .data( "autocomplete" )._renderItem = function( ul, item ) {
      return $( "<li></li>" )
        .data( "item.autocomplete", item )
        .append( "<a>" + item.label + "<br></a>" )
        .appendTo( ul );
    };
  }

  $(".confirm-delete").click(function() {
    make_confirm_dialog($(this), "Really delete?", "Confirm", "Cancel");
    return false;
  });

  $("#curs-ontology-transfer .upload-genes-link a").click(function() {
    function filter_func(i, e) {
      return $.trim(e.value).length > 0;
    }
    if ($(".annotation-comment").filter(filter_func).size() > 0) {
      make_confirm_dialog($(this), "Comment text will be lost.  Continue?", "Yes", "No");
      return false;
    }

    return true;
  });

  $("#curs-pub-send-session-popup-dialog").click(function() {
    make_confirm_dialog($(this), "Send link to session curator?", "Send", "Cancel");
  });

  $('button.curs-person-picker-add').click(function() {
    person_picker_add_person(this);
  });

  $('#curs-content').on('click', '.canto-more-button',
                        function(event) {
                          var this_id = $(event.currentTarget).attr('id');
                          var target = $('#' + this_id + '-target');
                          target.show();
                          $(event.currentTarget).hide();
                          event.stopPropagation();
                        });
});

$(document).ready(function() {
  $('.curs-js-link').show();
});
