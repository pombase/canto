"use strict";

/*global $,document,application_root */

function last(a) {
  return a[a.length-1];
}

function trim(a) {
  a=a.replace(/^\s+/,''); return a.replace(/\s+$/,'');
}

var loadingDiv = $('<div id="loading"><img src="' + application_root +
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
  $(".sect .undisclosed-title, .sect .disclosed-title").each(function(i) {
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

function make_ontology_complete_url(annotation_type) {
  return application_root + 'ws/lookup/ontology/' + annotation_type + '?def=1';
}

var ferret_choose = {
  // element 0 is the orginal text we searched for, last element is the current
  // selected term, the other elements are the history/trail
  term_history : [undefined],
  term_detail_cache : {},
  annotation_namespace: undefined,

  // the synonym we match when searching, if any
  matching_synonym : undefined,

  initialise : function(annotation_type_name, annotation_namespace) {
    ferret_choose.ontology_complete_url = make_ontology_complete_url(annotation_type);
    ferret_choose.annotation_type_name = annotation_type_name;
    ferret_choose.annotation_namespace = annotation_namespace;
  },

  debug : function(message) {
//    $("#ferret").append("<div>" + message + "</div>");
  },

  fetch_term_detail : function(term_id, callback) {
    var show_synonyms_config = annotation_type_config.show_synonyms;
    var synonyms_flag = 0;
    if (typeof(show_synonyms_config) !== "undefined") {
      if (show_synonyms_config === "always") {
        synonyms_flag = 1;
      }
    }
    $.ajax({
      url: ferret_choose.ontology_complete_url,
      data: { term: term_id, def: 1, children: 1, exact_synonyms: synonyms_flag },
      dataType: 'json',
      success: function(data) {
        callback(data[0]);
      },
    });
  },

  get_term_by_id : function(term_id, callback) {
    ferret_choose.fetch_term_detail(term_id, callback);
  },

  get_current_term : function() {
    return last(ferret_choose.term_history);
  },

  set_current_term : function(term_id) {
    $('#ferret-term-id').val(term_id);

    ferret_choose.debug("set_current_term: " + term_id);

    if (term_id) {
      if (term_id == 'search') {
        ferret_choose.term_history.length = 1;
      } else {
        var i;
        for (i = 1; i < ferret_choose.term_history.length; i++) {
          var value = ferret_choose.term_history[i];
          if (term_id == value) {
            // truncate the array, making term_id the last element
            ferret_choose.term_history.length = i + 1;
            break;
          }
        }

        if (i == ferret_choose.term_history.length) {
          ferret_choose.term_history.push(term_id);
        }
      }
    }
  },

  // if link has no fragment, go to search page
  move_to_hash_term : function(link) {
    var href = link.attr('href');
    var index = href.indexOf('#');
    if (index < 0) {
      ferret_choose.set_current_term();
    } else {
      var term_id = href.substring(index + 1);
      ferret_choose.set_current_term(term_id);
    }
  },

  term_click_handler : function(event) {
    ferret_choose.move_to_hash_term($(event.target));
    return false;
  },

  child_click_handler : function(event) {
    ferret_choose.move_to_hash_term($(event.target).closest('a'));
    return false;
  },

  show_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.show();
    ferret_choose.hide_leaf();
  },

  hide_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.hide();
  },

  show_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.show();
    ferret_choose.hide_children();
  },

  hide_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.hide();
  },

  suggest_dialog : function() {
    $('#ferret-suggest-term-id').val($('#ferret-term-id').val());
    var term_name = $('.ferret-term-name').first().text();
    $('#ferret-suggest').dialog({ modal: true,
                                  title:
                                  'Suggest a new child term of "' +
                                   term_name + '"',
                                  width: 800 });
    return false;
  },

  render : function(term) {
    if (ferret_choose.term_history.length <= 1) {
      var term_input = $('#ferret-term-input');
      term_input.focus();
      term_input.autocomplete('search');
    } else {
      var term_id = last(ferret_choose.term_history);

      $('.ferret-term-name').text(term.name);
      $('#ferret-term-definition').text(term.definition);
      $('.ferret-term-id-display').text(term_id);

      if (term.comment) {
        $('#ferret-term-comment-row').show();
        $('#ferret-term-comment').html('<div class="term-comment">' +
                                       term.comment + '</div>');
      } else {
        $('#ferret-term-comment-row').hide();
        $('#ferret-term-comment').html('');
      }

      if (ferret_choose.matching_synonym && ferret_choose.term_history.length == 2) {
        $('#ferret-term-matching-synonym-row').show();
        $('#ferret-term-matching-synonym').html('<div class="term-synonym">' +
                                       ferret_choose.matching_synonym + '</div>');
      } else {
        $('#ferret-term-matching-synonym-row').hide();
        $('#ferret-term-matching-synonym').html('');
      }

      var synonyms_html = '';
      var synonyms_count = 0;

      if ("synonyms" in term) {
        $.each(term.synonyms, function(idx, synonym) {
          var synonym_name = synonym.name;
          if (synonym_name !== ferret_choose.matching_synonym) {
            synonyms_html += '<li>' + synonym_name + '</li>';
            synonyms_count++;
          }
        });
      }

      $('#ferret-term-synonyms-row').remove();
      if (synonyms_count > 0) {
        var synonym_title = 'Synonym';
        if (synonyms_count > 1) {
          synonym_title = 'Synonyms';
        }
        var $new_synonym_row = $('<tr id="ferret-term-synonyms-row">' +
                                 '<td class="title">' + synonym_title + '</td>' +
                                 '<td>' + synonyms_html + '</td></tr>');

        $('#ferret-term-matching-synonym-row').after($new_synonym_row);
      }

      ferret_choose.debug("render(): " + term_id + " " + term.name);

      var children = term.children;
      var children_html = '';

      $.each(children, function(idx, child) {
        var img_html =
          '<img src="' + application_root + 'static/images/right_arrow.png"/>';
        children_html += '<li><a href="#' + child.id + '">' +
          child.name + img_html + '</li></a>';
      });

      $('#ferret-term-children').data('child-count', children.length);
      $('#ferret-term-children-list').html($('<ul/>').append($(children_html)));

      if (children.length == 0) {
        ferret_choose.show_leaf();
      } else {
        ferret_choose.show_children();
      }

      var link_confs = ontology_external_links[ferret_choose.annotation_namespace];
      if (link_confs) {
        var html = '';
        $.each(link_confs, function(idx, link_conf) {
          var url = link_conf['url'];
          // hacky: allow a substitution like WebUtil::substitute_paths()
          var re = new RegExp("@@term_ont_id(?::s/(.+)/(.*)/r)?@@");
          url = url.replace(re,
                            function(match_str, p1, p2) {
                              if (!p1 || p1.length == 0) {
                                return term_id;
                              } else {
                                return term_id.replace(new RegExp(p1), p2);
                              }
                            });
          var img_src =
            application_root + 'static/images/logos/' +
            link_conf['icon'];
          var title = 'View in: ' + link_conf['name'];
          html += '<div class="curs-external-link"><a target="_blank" href="' +
            url + '" title="' + title + '">';
          if (img_src) {
            html += '<img alt="' + title + '" src="' + img_src + '"/></a>'
          } else {
            html += title;
          }
          var link_img_src = application_root + 'static/images/ext_link.png';
          html += '<img src="' + link_img_src + '"/></div>';
        });
        var $linkouts = $('#ferret-linkouts');
        if (html.length > 0) {
          $linkouts.find('.links-container').html(html);
          $linkouts.show();
        } else {
          $linkouts.hide();
        }
      }
    }
  },

  ferret_reset : function() {
    // from: http://stackoverflow.com/questions/680241/blank-out-a-form-with-jquery
    $(':input','#ferret-form')
      .not(':button, :submit, :reset, :hidden')
      .val('')
      .removeAttr('checked')
      .removeAttr('selected');
    ferret_choose.term_history = [ferret_choose.term_history.first()];
    return true;
  },

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
}


var curs_home = {
  show_term_suggestion : function(term_ontid, name, definition) {
    var dialog_div = $('#curs-dialog');
    var html = '<div><h4>Term name:</h4>' +
      '<span class="term-name">' + name + '</span></div>' +
      '<div>' +
      '<h4>Definition:</h4> <div class="term-definition">' + definition +
      '</div></div>';
    $('#curs-dialog').html(html);
    $('#curs-dialog').dialog({ modal: true,
                               title: 'Child term suggestion for ' + term_ontid});
  }

};

var canto_util = {
  show_message : function(title, message) {
    var dialog_div = $('#curs-dialog');
    var html = '<div>' + message + '</div>';
    $('#curs-dialog').html(html);
    $('#curs-dialog').dialog({ modal: true,
                               title: title});
  }
};

$(document).ready(function() {
  $('input[type=checkbox]').shiftcheckbox();

  $('a.canto-select-all').click(function () {
    $(this).closest('div').find('input:checkbox').attr('checked', true);
  });

  $('a.canto-select-none').click(function () {
    $(this).closest('div').find('input:checkbox').removeAttr('checked');
  });

  $('#curs-finish-session').click(function () {
    window.location.href = curs_root_uri + '/finish_form';
  });

  $('#curs-pause-session').click(function () {
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

  $('#curs-finish-gene,#curs-finish-genotype').on('click',
                                                  function () {
                                                    window.location.href = curs_root_uri;
                                                  });

  $('#curs-pub-assign-popup-dialog').click(function () {
    $('#curs-pub-assign-dialog').dialog({ modal: true,
                                          title: 'Set the corresponding author ...',
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
    window.location.href = application_root + 'tools/triage?triage-return-pub-id=' + $(this).val();
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
      title: 'Add a person ...',
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
    } else {
      $dialog.dialog('close');
      var $form = $dialog.find('form');
      return true;
    }
  });

  $('#pubmed-id-lookup-form').ajaxForm({
    dataType: 'json',
    success: function(data) {
      $('#pubmed-id-lookup-waiting .ajax-spinner').hide();
      $('#pubmed-id-existing-sessions').hide();
      $('#pubmed-id-lookup-message').hide();
      if (data.pub) {
        $('#pub-details-uniquename').data('pubmedid', data.pub.uniquename);
        $('#pub-details-uniquename').data('pub_id', data.pub.pub_id);
        if ("curation_sessions" in data) {
          $('#pubmed-id-existing-sessions').show();
          $('#pubmed-id-existing-sessions span:first').html(data.message);
          var $link = $('#pubmed-id-pub-link a');
          if ($link.size()) {
            var href = $link.attr('href');
            href = href.replace(new RegExp("(.*)/(.*)%3F(.*)"), "$1/" + data.pub.pub_id + "?$3");
            $link.attr('href', href);
          }
        } else {
          $('#pub-details-uniquename').html(data.pub.uniquename);
          $('#pub-details-title').html(data.pub.title);
          $('#pub-details-authors').html(data.pub.authors);
          var $abstract_details = $('#pub-details-abstract');
          $abstract_details.html(data.pub['abstract']);
          add_jTruncate($abstract_details);
          $('#pubmed-id-lookup').hide();
          $('#pubmed-id-lookup-pub-results').show();
        }
      } else {
        $('#pubmed-id-lookup-message').show();
        $('#pubmed-id-lookup-message span').html(data.message);
      }
    }
  });

  $('#pubmed-id-lookup-reset').click(function () {
    $('#pubmed-id-lookup-waiting .ajax-spinner').hide();
    $('#pubmed-id-lookup-pub-results').hide();
    $('#pubmed-id-lookup-input').val('');
    $('#pubmed-id-lookup').show();
  });

  $('#pubmed-id-lookup-curate').click(function () {
    var pubmedid = $('#pub-details-uniquename').data('pubmedid');
    window.location.href = application_root + '/tools/start/' + pubmedid;
  });

  $('#pubmed-id-lookup-goto-pub-session').click(function () {
    var pub_id = $('#pub-details-uniquename').data('pub_id');
    window.location.href = application_root + '/tools/pub_session/' + pub_id;
  });

  function add_jTruncate($element) {
    $element.jTruncate({
      length: 300,
      minTrail: 50,
      moreText: "[show all]",
      lessText: "[hide]"
    });
  }

  add_jTruncate($('.non-key-attribute'));

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

  $(".confirm-delete").click(function(e) {
    make_confirm_dialog($(this), "Really delete?", "Confirm", "Cancel");
    return false;
  });

  $("#curs-ontology-transfer .upload-genes-link a").click(function(e) {
    function filter_func(i, e) {
      return $.trim(e.value).length > 0;
    }
    if ($(".annotation-comment").filter(filter_func).size() > 0) {
      make_confirm_dialog($(this), "Comment text will be lost.  Continue?", "Yes", "No");
      return false;
    } else {
      return true
    }
  });

  $("#curs-pub-send-session-popup-dialog").click(function(e) {
    make_confirm_dialog($(this), "Send link to session curator?", "Send", "Cancel");
  });

  $('button.curs-person-picker-add').click(function(e) {
    person_picker_add_person(this);
  });
});

$(document).ready(function() {
  $('.curs-js-link').show();
});
