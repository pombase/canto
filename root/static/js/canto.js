"use strict";

function last(a) {
  return a[a.length-1];
}

function trim(a) {
  a=a.replace(/^\s+/,''); return a.replace(/\s+$/,'');
}

$(document).ready(function() {
  var loadingDiv = $('<div id="loading"><img src="' + application_root +
                     '/static/images/spinner.gif"/></div>');
  loadingDiv
    .prependTo('body')
    .position({
      my: 'center',
      at: 'center',
      of: $('#content'),
      offset: '0 200'
    })
    .hide()  // hide it initially
    .bind('ajaxStart.canto', function() {
      $(this).show();
      $('#content').addClass('faded-overlay');
    })
    .bind('ajaxStop.canto', function() {
      $(this).hide();
      $('#content').removeClass('faded-overlay');
    });
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

  initialise : function(annotation_type, annotation_namespace) {
    ferret_choose.ontology_complete_url = make_ontology_complete_url(annotation_type);
    ferret_choose.annotation_type = annotation_type;
    ferret_choose.annotation_namespace = annotation_namespace;
  },

  debug : function(message) {
//    $("#ferret").append("<div>" + message + "</div>");
  },

  store_term_data : function(data) {
    var term = data[0];
    ferret_choose.debug("adding to cache: " + term.id + " " + term.name);
    ferret_choose.term_detail_cache[term.id] = term;
  },

  fetch_term_detail : function(term_id) {
    ferret_choose.debug("fetching: " + term_id);
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
      success: ferret_choose.store_term_data,
      async: false
    });
    $('#ferret-term-entry').hide();
  },

  get_term_by_id : function(term_id) {
    if (!ferret_choose.term_detail_cache[term_id]) {
      ferret_choose.fetch_term_detail(term_id);
    }

    ferret_choose.debug("looking for in cache: " + term_id);
    ferret_choose.debug("returning from cache: " + ferret_choose.term_detail_cache[term_id]);
    var term = ferret_choose.term_detail_cache[term_id];

    return term;
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

    var bbq_state = {
      "s" : ferret_choose.term_history[0],
      "c" : ferret_choose.term_history.slice(1).join(",")
    };

    $.bbq.pushState(bbq_state);
  },

  add_to_breadcrumbs : function(term, make_link) {
    var dest = $('#breadcrumbs-search');
    // find the most nested div
    while (true) {
      var children = dest.children('div');
      if (children.length > 0) {
        dest = children.first();
      } else {
        break;
      }
    }
    var link_start;
    var link_end;

    if (make_link) {
      link_start = '<a title="' + term.name + '" href="#' + term.id + '">';
      link_end = '</a>';
    } else {
      link_start = '';
      link_end = '';
    }
    var div = $('<div class="breadcrumbs-link breadcrumbs-ferret-term">' +
                link_start + term.name + link_end + '</div>');
    div.data('term', term);
    dest.append(div);
  },

  render_breadcrumbs : function(term_id) {
    $('#breadcrumbs-search').remove();
    var history_length = ferret_choose.term_history.length;
    var search_string = ferret_choose.term_history[0];

    if (!search_string) {
      search_string = '';
    }

    var link_start;
    var link_end;
    if (history_length > 1) {
      link_start = '<a href="#search">';
      link_end = '</a>';
    } else {
      link_start = '';
      link_end = '';
    }
    var search_text;
    if (search_string.length == 0) {
      search_text = "Search";
    } else {
      search_text = 'Search: "' + search_string + '"';
    }
    var html = '<div class="breadcrumbs-link" id="breadcrumbs-search">' +
      link_start + search_text + link_end +
      '</div>';
    $('#breadcrumbs-gene-link').append(html);

    if (ferret_choose.term_history.length > 1) {
      for (var i = 1; i < history_length; i++) {
        var term_id = ferret_choose.term_history[i];
        var term = ferret_choose.get_term_by_id(term_id);
        var make_link = (i != history_length - 1);
        ferret_choose.add_to_breadcrumbs(term, make_link);
      }
    };
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

  render : function() {
    if (ferret_choose.term_history.length <= 1) {
      $('#ferret-term-details').hide();
      $('#ferret-term-entry').show();

      var term_input = $('#ferret-term-input');
      term_input.focus();
      term_input.autocomplete('search');
    } else {
      $('#ferret-term-details').show();
      $('#ferret-term-entry').hide();

      var term_id = last(ferret_choose.term_history);
      var term = ferret_choose.get_term_by_id(term_id);

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

    ferret_choose.render_breadcrumbs();
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

function make_ferret_name_input(search_namespace, ferret_input, select_callback) {
  function render_term_item(ul, item, search_string, search_namespace) {
    var search_bits = search_string.split(/\W+/);
    var match_name = item.matching_synonym;
    var synonym_extra = '';
    if (match_name) {
      synonym_extra = ' (synonym)';
    } else {
      match_name = item.name;
    }
    var warning = '';
    if (search_namespace !== item.annotation_namespace) {
      warning = '<br/><span class="autocomplete-warning">WARNING: this is the ID of a ' +
        item.annotation_namespace + ' term but<br/>you are browsing ' +
        search_namespace + ' terms</span>';
      var re = new RegExp('_', 'g');
      // unpleasant hack to make the namespaces look nicer
      warning = warning.replace(re,' ');
    }
    function length_compare(a,b) {
      if (a.length < b.length) {
        return 1;
      } else {
        if (a.length > b.length) {
          return -1;
        } else {
          return 0;
        }
      }
    };
    search_bits.sort(length_compare);
    for (var i = 0; i < search_bits.length; i++) {
      var bit = search_bits[i];
      if (bit.length > 1) {
        var re = new RegExp('(\\b' + bit + ')', "gi");
        match_name = match_name.replace(re,'<b>$1</b>');
      }
    }
    return $( "<li></li>" )
      .data( "item.autocomplete", item )
      .append( "<a>" + match_name + " <span class='term-id'>(" +
               item.id + ")</span>" + synonym_extra + warning + "</a>" )
      .appendTo( ul );
  };


  ferret_input.autocomplete({
    minLength: 2,
    source: make_ontology_complete_url(search_namespace),
    cacheLength: 100,
    focus: ferret_choose.show_autocomplete_def,
    close: ferret_choose.hide_autocomplete_def,
    select: select_callback
  }).data("autocomplete")._renderItem = function( ul, item ) {
    var search_string = ferret_input.val();
    return render_term_item(ul, item, search_string, search_namespace);
  };

  function do_autocomplete () {
    ferret_input.focus();
    ferret_input.autocomplete('search');
  }

  ferret_input.bind('paste', function() {
      setTimeout(do_autocomplete, 10);
    });

  ferret_input.keypress(function(event) {
      if (event.which == 13) {
        // return should autocomplete not submit the form
        event.preventDefault();
        ferret_input.autocomplete('search');
      }
    });


}

$(document).ready(function() {
  var ferret_input = $("#ferret-term-input");

  if (ferret_input.size()) {
    $('#loading').unbind('.canto');

    var select_callback = function(event, ui) {
      ferret_choose.term_history = [trim(ferret_input.val())];
      ferret_choose.set_current_term(ui.item.id);
      ferret_choose.matching_synonym = ui.item.matching_synonym;
      return false;
    };

    make_ferret_name_input(ferret_choose.annotation_namespace, ferret_input, select_callback);

    $("body").delegate("#ferret-term-children-list a", "click",
                       ferret_choose.child_click_handler);
    $("body").delegate("#breadcrumbs .breadcrumbs-term a", "click",
                       ferret_choose.term_click_handler);
    $("body").delegate("#breadcrumbs-search a", "click",
                       ferret_choose.term_click_handler);

    $("#breadcrumb-previous-button").click(function () {
      ferret_choose.term_history.length -= 1;
      if (ferret_choose.term_history.length > 0) {
        if (ferret_choose.term_history.length == 1) {
          ferret_choose.set_current_term();
        } else {
          ferret_choose.set_current_term(last(ferret_choose.term_history));
        }
      } else {
        window.location.href = curs_root_uri;
      }
    });

    $('#ferret-term-input').attr('disabled', false);

    $('#ferret-suggest-link').click(ferret_choose.suggest_dialog);
    $('#ferret-suggest-link-leaf').click(ferret_choose.suggest_dialog);

    $("#ferret-suggest-form").validate({
      rules: {
        'ferret-suggest-name': "required",
        'ferret-suggest-definition': "required"
      },
      messages: {
        'ferret-suggest-name': "Please enter a name for the term",
        'ferret-suggest-definition': "Please enter a definition for the term"
      }
    });

    $("#curs-contact-form").validate({
      rules: {
        'curs-contact-name': "required",
        'curs-contact-definition': "required"
      },
      messages: {
        'curs-contact-name': "Please enter a name for the term",
        'curs-contact-definition': "Please enter a definition for the term"
      }
    });

    $('.canto-toggle-button').each(function (index, element) {
      var this_id = $(element).attr('id');
      var target = $('#' + this_id + '-target');
      $(element).click(
        function () {
          target.toggle()
        }
      );
      $(element).show();
    });

    $('.canto-more-button').each(function (index, element) {
      var this_id = $(element).attr('id');
      var target = $('#' + this_id + '-target');
      $(element).click(
        function () {
          target.show()
          $(element).hide();
          return false;
        }
      );
      $(element).show();
    });

    $(window).bind('hashchange', function(e) {
      var state = $.bbq.getState( this.id, true );
      var search_string = state.s;

      if (search_string) {
        if (state.c) {
          var crumbs = trim(state.c);
          var new_history = [search_string].concat(crumbs.split(","));
          ferret_choose.term_history = new_history
          $('#ferret-term-id').val(last(new_history));
        } else {
          ferret_choose.term_history = [search_string];
        }
      } else {
        ferret_choose.term_history = [];
      }

      $('#ferret-term-input').val(search_string);

      ferret_choose.render();
    })

    $(window).trigger( 'hashchange' );
  } else {

    $('#breadcrumb-previous-button').click(function () {
      window.location.href = curs_root_uri;
    });

  }

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
