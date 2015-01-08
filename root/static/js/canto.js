function last(a) {
  return a[a.length-1];
}

function trim(a) {
  a=a.replace(/^\s+/,''); return a.replace(/\s+$/,'');
};

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
    ferret_choose.allele_lookup_url = application_root + 'ws/lookup/allele';
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
  },
};


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

  $('#curs-finish-gene').click(function () {
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
          $abstract_details.html(data.pub.abstract);
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

var AlleleStuff = function($) {
  function add_allele_row($allele_table, data, $previous_row) {
    $allele_table.show();
    var name = data['name'];
    if (name == null) {
      name = 'noname';
    }
    var description = data['description'];
    if (description == null) {
      description = 'unknown';
    }
    var expression = data['expression']
    if (expression == null) {
      expression = 'null';
    }
    var conditions;
    if (typeof(data['conditions']) == 'undefined') {
      conditions = '';
    } else {
      conditions = data['conditions'].join(', ')
    }

    $('#curs-add-allele-proceed').show();

    var row_html =
      '<td>' + name + '</td>' +
      '<td>' + description + '</td>' +
      '<td>' + data.allele_type + '</td>' +
      '<td>' + expression + '</td>' +
      '<td>' + data['evidence'] + '</td>' +
      '<td>' + conditions + '</td>' +
      '<td><img class="curs-allele-delete-row" src="' + delete_icon_uri + '"></td>';;
    if ($allele_table.find('th.curs-allele-edit-link-header').length > 0) {
      row_html += '<td><a href="#" class="curs-allele-edit-row" id="curs-allele-edit-row-data-' + delete['id'] + '">edit&nbsp;...</a></td>';
    }
    var $new_row = $('<tr class="curs-allele-select-row">' + row_html + '</tr>');
    if (typeof($previous_row) == 'undefined') {
      $allele_table.find('tbody').append($new_row);
    } else {
      $previous_row.after($new_row);
    }
    $new_row.data('allele_id', data['id']);
    $new_row.data('allele_type', data['allele_type']);

    if ($.grep(existing_alleles_by_name,
               function(el) {
                 return el.value === name && el.description === description;
               }).length == 0) {
      existing_alleles_by_name.push({ value: name, description: description,
                                      allele_type: data.allele_type,
                                      display_name: data.display_name });
    }

    $new_row.data('allele_data', data);

    return $new_row;
  }

  function fetch_conditions(search, showChoices) {
    $.ajax({
      url: make_ontology_complete_url('phenotype_condition'),
      data: { term: search.term, def: 1, },
      dataType: "json",
      success: function(data) {
        var choices = $.map( data, function( item ) {
          var label;
          if (item.matching_synonym == null) {
            label = item.name;
          } else {
            label = item.matching_synonym + ' (synonym)';
          }
          return {
            label: label,
            value: item.name,
            name: item.name,
            definition: item.definition,
          }
        });
        showChoices(choices);
      },
    });
  };

  var used_conditions;

  function make_condition_buttons($allele_dialog, $allele_table) {
    $allele_table.find('tr').map(function(idx, el) {
      var el_allele_data = $(el).data('allele_data');
      if (typeof(el_allele_data) != 'undefined') {
        $.map(el_allele_data.conditions,
              function(cond, idx) {
                used_conditions[cond] = true;
              });
      }
    });
    var button_html = '';

    var used_buttons = $allele_dialog.find('.curs-allele-condition-buttons');

    used_buttons.find('button').remove();

    $.each(used_conditions,
           function(cond) {
             button_html += '<button class="ui-widget ui-state-default curs-allele-condition-button">' +
               '<span>' + cond + '</span></button>';
           });

    if (button_html === '') {
      used_buttons.hide();
    } else {
      used_buttons.show();
      used_buttons.append(button_html);

      $('.curs-allele-condition-buttons button').click(function() {
        get_allele_conditions_jq($allele_dialog).tagit("createTag", $(this).find('span').text());
        return false;
      }).button({
        icons: {
          secondary: "ui-icon-plus"
        }
      });
    }
  }

  function add_allele_confirm($allele_dialog, $allele_table) {
    var $form = $('#curs-allele-add form');
    $form.find('.curs-allele-description-input').removeAttr('disabled');
    var $orig_allele_row = $allele_dialog.data('edit_allele_row');
    var $reuse_checkbox = $form.find('input[name="curs-allele-reuse-dialog"]');
    var $reuse_checkbox_checked = $reuse_checkbox.is(':checked');
    if (!$allele_dialog.data('validate_on_add') || $form.validate().form()) {
      $form.find('.curs-allele-name').attr('disabled', false);
      $form.ajaxSubmit({
        dataType: 'json',
        success: function(data) {
          try {
            var $new_row = add_allele_row($allele_table, data, $orig_allele_row);
            if (typeof($orig_allele_row) !== 'undefined') {
              $orig_allele_row.detach();
              remove_db_allele($orig_allele_row, false);
            }
            $new_row.effect("highlight", { color: "#aaf" }, 2500);
          } catch (err) {
            $allele_table.append($orig_allele_row);
          }
          if (editing_allele) {
            if ($reuse_checkbox_checked) {
              // we're not editing any more
              editing_allele = false;
              $allele_dialog.removeData('edit_allele_row');
            } else {
              window.location.href = curs_root_uri + '/annotation/process_alleles/' + annotation_id + '/edit';
            }
          }
          if ($reuse_checkbox_checked) {
            make_condition_buttons($allele_dialog, $allele_table);
          }
        },
        timeout: 10000,
      });
      $('#curs-allele-add .curs-allele-conditions').tagit("removeAll");
      if ($reuse_checkbox_checked) {
        $.pnotify({
          pnotify_title: 'Notice',
          pnotify_text: 'Allele successfully added',
        });
        $reuse_checkbox.attr('checked', false);
      } else {
        if (!editing_allele) {
          $allele_dialog.dialog("close");
        }
      }
    }
  }

  function add_allele_cancel() {
    if (editing_allele) {
      window.location.href = curs_root_uri + '/annotation/process_alleles/' + annotation_id + '/edit';
    } else {
      $(this).dialog("close");
    }
  }

  function set_expression($allele_dialog, value) {
    var $expression_row = $allele_dialog.find('.curs-allele-expression');
    $expression_row.find('input[value="' + value + '"]').attr('checked', true);
  }

  function unset_expression($allele_dialog) {
    var $expression_row = $allele_dialog.find('.curs-allele-expression');
    $expression_row.find('input').attr('checked', false);
  }

  function hide_allele_description($allele_dialog) {
    $allele_dialog.find('.curs-allele-type-description').hide();
    $allele_dialog.find('.curs-allele-description-input').val('');
    $allele_dialog.find('.curs-allele-type-select').show();
    unset_expression($allele_dialog);
    var name_input = get_allele_name_jq($allele_dialog);
    name_input.removeAttr('disabled');
    var label = $allele_dialog.find('.curs-allele-type-label');
    label.hide();
  };

  function maybe_autopopulate(allele_type_config, name_input) {
    if (typeof allele_type_config.autopopulate_name != 'undefined') {
      var new_name =
        allele_type_config.autopopulate_name.replace(/@@gene_name@@/, gene_display_name);
      name_input.val(new_name);
      return true;
    }
    return false;
  }

  function setup_description($allele_dialog, selected_option) {
    var description = $allele_dialog.find('.curs-allele-type-description');
    description.show();
    var description_input = description.find('input');
    var selected_text = selected_option.text();
    var allele_type_config = allele_types[selected_text];
    var label = $allele_dialog.find('.curs-allele-type-label');
    var description_example = $('#curs-allele-description-example');
    description_example.html('');

    if (allele_type_config.description_required == 1) {
      label.show();
      label.find('span').text(selected_text);
      var description_placeholder_text = allele_type_config.placeholder;
      if (allele_type_config.placeholder !== '') {
        description_example.html(description_placeholder_text);
      }
      description_input.removeAttr('disabled');
      description_input.attr('placeholder', '');
    } else {
      label.hide();
      description_input.attr('placeholder', selected_text);
      description_input.attr('disabled', true);
    }
    description_input.placeholder();

    var $expression_span = $allele_dialog.find('.curs-allele-expression');
    var $endogenous_input = $expression_span.find("input[value='Endogenous']");

    if (allele_type_config.allow_expression_change == 1) {
      $expression_span.show();
    } else {
      $expression_span.hide();
      unset_expression($allele_dialog);
    }

    var $endogenous_div = $endogenous_input.parent('div');
    var $not_specified_div = $expression_span.find("input[value='Not specified']").parent('div');
    var $null_div = $expression_span.find("input[value='Null']").parent('div');
    if (allele_type_config.name === 'wild type') {
      $endogenous_div.hide();
      $endogenous_input.attr('checked', false);
      $not_specified_div.hide();
      $not_specified_div.attr('checked', false);
      $null_div.hide();
      $null_div.attr('checked', false);
    } else {
      $endogenous_div.show();
      $not_specified_div.show();
    }

    setup_allele_name($allele_dialog, allele_type_config);

    // hack to make sure all contents are visible, from:
    // http://stackoverflow.com/a/10457932
    $allele_dialog.css('height', '');
    // recentre:
    $('#curs-allele-add').parent('.ui-dialog').position({ of: $(window) });
  }

  function setup_allele_name($allele_dialog, allele_type_config) {
    var name_input = get_allele_name_jq($allele_dialog);

    name_input.attr('disabled', false);

    if (typeof(allele_type_config) === 'undefined') {
      name_input.attr('placeholder', 'Allele name (optional)');
    } else {
      var autopopulated = maybe_autopopulate(allele_type_config, name_input);

      if (allele_type_config.allele_name_required == 1 && !autopopulated) {
        name_input.attr('placeholder', 'Allele name required');
      } else {
        name_input.attr('placeholder', 'Allele name (optional)');
      }

      if (autopopulated) {
        name_input.data('autopopulated_name', name_input.val());
        name_input.attr('disabled', true);
      }
    }
  }

  function setup_allele_form_validate(add_allele_dialog) {
    add_allele_dialog.find('form').validate({
      rules: {
        'curs-allele-type': {
          required: true,
        },
        'curs-allele-name': {
          required: function() {
            var selected_text = get_allele_type_select_jq(add_allele_dialog).val();
            var allele_type_config = allele_types[selected_text];
            if (typeof(allele_type_config) == 'undefined') {
              return false;
            } else {
              return allele_type_config.allele_name_required == 1;
            }
          }
        },
        'curs-allele-description-input': {
          required: function() {
            var selected_text = get_allele_type_select_jq(add_allele_dialog).val();
            var allele_type_config = allele_types[selected_text];
            if (typeof(allele_type_config) == 'undefined') {
              return false;
            } else {
              return allele_type_config.description_required == 1;
            }
          }
        },
        'curs-allele-evidence-select': {
          required: true
        },
        'curs-allele-expression': {
          required: function() {
            var selected_text = get_allele_type_select_jq(add_allele_dialog).val();
            var allele_type_config = allele_types[selected_text];
            if (typeof(allele_type_config) == 'undefined') {
              return false;
            } else {
              return allele_type_config.allow_expression_change == 1;
            }
          }
        }
      }
    });
  }

  function remove_allele_row($tr) {
    if ($tr.closest('tbody').children('tr').size() == 1) {
      $tr.closest('table').hide();
      $('#curs-add-allele-proceed').hide();
    }
    $tr.remove();
  }

  function remove_db_allele($tr, async) {
    var allele_id = $tr.data('allele_id');

    $.ajax({
      url: curs_root_uri + '/annotation/remove_allele_action/' + annotation_id +
        '/' + allele_id,
      cache: false,
      async: async
    }).done(function() {
      remove_allele_row($tr);
    });
  }

  function get_allele_name_jq ($allele_dialog) {
    return $allele_dialog.find('.curs-allele-name');
  }
  function get_allele_desc_jq ($allele_dialog) {
    return $allele_dialog.find('.curs-allele-description-input');
  }
  function get_allele_type_select_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-type-select select')
  }
  function get_allele_type_label_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-type-label-span');
  }
  function get_allele_evidence_select_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-evidence-select');
  }
  function get_allele_expression_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-expression'); 
  }
  function get_allele_conditions_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-conditions');
  }

  function populate_dialog_from_data($allele_dialog, data) {
    get_allele_name_jq($allele_dialog).val(data.name);
    get_allele_desc_jq($allele_dialog).val(data.description);
    get_allele_type_select_jq($allele_dialog).val(data.allele_type).trigger('change');
    get_allele_evidence_select_jq($allele_dialog).val(data.evidence);
    if ("expression" in data) {
      set_expression($allele_dialog, data.expression);
    } else {
      unset_expression($allele_dialog);
    }
    if ("conditions" in data) {
      $.map(data.conditions, function(item) {
        get_allele_conditions_jq($allele_dialog).tagit("createTag", item);
      });
    };
  }

  function init() {
    var $allele_dialog = $('#curs-allele-add');
    var $allele_table = $('#curs-allele-list');

    if (typeof(current_conditions) != 'undefined') {
      used_conditions = current_conditions;
    }

    $allele_dialog.data('validate_on_add', true);

    $($allele_table).on('click', '.curs-allele-delete-row', function (ev) {
      var $tr = $(this).closest('tr');
      remove_db_allele($tr, true);
    });

    $('#curs-add-allele-details').click(function () {
      add_allele_dialog.dialog("option", "buttons", add_allele_buttons);
      add_allele_dialog.dialog("open");
      $allele_dialog.data('validate_on_add', true);
      $(add_allele_dialog).removeData('allele_data');
      return false;
    });

    var add_allele_buttons = [
      {
        text: "Cancel",
        click: add_allele_cancel,
      },
      {
        text: "Add",
        click: function() {
          add_allele_confirm($allele_dialog, $allele_table);
        },
      },
    ];

    var edit_allele_buttons = [
      {
        text: "Cancel",
        click: add_allele_cancel,
      },
      {
        text: "Edit",
        click: function() {
          add_allele_confirm($allele_dialog, $allele_table);
        },
      },
    ];

    function allele_lookup(request, response) {
      $.ajax({
        url: ferret_choose.allele_lookup_url,
        data: { gene_primary_identifier: gene_primary_identifier,
                ignore_case: true,
                term: request.term },
        dataType: 'json',
        success: function(data) {
          var results =
              $.grep(
                existing_alleles_by_name,
                function(el) {
                  return typeof(el.value) !== 'undefined' &&
                    el.value.toLowerCase().indexOf(request.term.toLowerCase()) == 0;
                })
              .concat($.map(
                data,
                function(el) {
                  return {
                    value: el.name,
                    display_name: el.display_name,
                    description: el.description,
                    allele_type: el.allele_type
                  }
                }));
          response(results);
        },
        async: true
      });
    }

    var add_allele_dialog = $allele_dialog.dialog({
      modal: true,
      autoOpen: false,
      height: 'auto',
      width: 600,
      title: 'Add an allele for this phenotype',
      buttons : add_allele_buttons,
      open: function() {
        $('#curs-allele-add .curs-allele-name').autocomplete({
          source: allele_lookup,
          select: function(event, ui) {
            var $description = get_allele_desc_jq($allele_dialog).val(ui.item.description);
            get_allele_type_select_jq($allele_dialog).val(ui.item.allele_type).trigger('change');
          }
        }).data("autocomplete" )._renderItem = function(ul, item) {
          return $( "<li></li>" )
            .data( "item.autocomplete", item )
            .append( "<a>" + item.display_name + "</a>" )
            .appendTo( ul );
        };

        make_condition_buttons($allele_dialog, $allele_table);

        hide_allele_description(add_allele_dialog);
        get_allele_type_select_jq(add_allele_dialog).val(undefined).trigger('change');
        add_allele_dialog.find('.curs-allele-name').val('');
        var name_input = add_allele_dialog.find('.curs-allele-name');
        name_input.attr('placeholder', 'Allele name (optional)');

        setup_allele_form_validate(add_allele_dialog);
      },
      close: function() {
        get_allele_evidence_select_jq($allele_dialog).val('');
      }
    });

    function edit_row($tr) {
      var allele_id = $tr.data('allele_id');
      add_allele_dialog.dialog("option", "buttons", edit_allele_buttons);
      add_allele_dialog.dialog("open");
      var allele_data = $tr.data('allele_data');
      populate_dialog_from_data($allele_dialog, allele_data);
      $allele_dialog.data('validate_on_add', false);
      $(add_allele_dialog).data('edit_allele_row', $tr);
    }

    $($allele_table).on('click', '.curs-allele-edit-row', function (ev) {
      var $tr = $(this).closest('tr');
      edit_row($tr);
    });

    $('#curs-allele-add .curs-allele-conditions').tagit({
      minLength: 2,
      fieldName: 'curs-allele-condition-names',
      allowSpaces: true,
      placeholderText: 'Type a condition ...',
      tagSource: fetch_conditions,
      autocomplete: {
        focus: ferret_choose.show_autocomplete_def,
        close: ferret_choose.hide_autocomplete_def,
      },
    });

    $allele_dialog.on('click', '.curs-allele-description-delete', function () {
      var $button = $(this);
      hide_allele_description($allele_dialog);
      get_allele_type_select_jq($allele_dialog).val(undefined).trigger('change');
      var name_input = get_allele_name_jq($allele_dialog);
      $('#curs-allele-description-example').html('');
      if (typeof(name_input.data('autopopulated_name')) != 'undefined' &&
          name_input.val() === name_input.data('autopopulated_name')) {
        // clear the name if we created it
        name_input.val('');
      }
    });

    $allele_dialog.on('change', '.curs-allele-type-select select', function (ev) {
      var $this = $(this);
      $this.closest('tr').hide();
      var selected_option = $this.children('option[selected]');
      var name_input = get_allele_name_jq($allele_dialog);
      $allele_dialog.data('validate_on_add', true);
      if (selected_option.val() === '') {
        hide_allele_description($allele_dialog);
        get_allele_expression_jq($allele_dialog).hide();
        var selected_text = selected_option.text();
        var allele_type_config = allele_types[selected_text];
        setup_allele_name($allele_dialog, allele_type_config);
        return;
      }
      setup_description($allele_dialog, selected_option);
    });

    if (typeof(alleles_in_progress) != 'undefined') {
      $.each(alleles_in_progress,
             function(key, value) {
               add_allele_row($allele_table, value);
             });

      $('#curs-add-allele-proceed').click(function() {
        window.location.href = curs_root_uri + '/annotation/process_alleles/' + annotation_id +
          (editing_allele ? '/edit' : '');
      });

      if (editing_allele) {
        var $tr = $('#curs-allele-list .curs-allele-select-row');
        edit_row($tr);
      }
    }
  }

  return {
    pageInit: init
  };
}($);

var EditDialog = function($) {
  function confirm($dialog) {
    var $form = $('#curs-edit-dialog form');
    $dialog.dialog('close');
    $('#loading').unbind('ajaxStop.canto');
    $form.ajaxSubmit({
          dataType: 'json',
          success: function(data) {
            $dialog.dialog("destroy");
            var $dialog_div = $('#curs-edit-dialog');
            $dialog_div.remove();
            window.location.reload(false);
          }
        });
  }

  function cancel() {
    $(this).dialog("destroy");
    var $dialog_div = $('#curs-edit-dialog');
    $dialog_div.remove();
  }

  function create(title, current_comment, form_url) {
    var $dialog_div = $('#curs-edit-dialog');
    if ($dialog_div.length) {
      $dialog_div.remove()
    }

    var dialog_html =
      '<div id="curs-edit-dialog" style="display: none">' +
      '<form action="' + form_url + '" method="post">' +
      '<textarea rows="8" cols="70" name="curs-edit-dialog-text">' + current_comment +
      '</textarea></form></div>';

    $dialog_div = $(dialog_html);

    var $dialog = $dialog_div.dialog({
      modal: true,
      autoOpen: true,
      height: 'auto',
      width: 600,
      title: title,
      buttons : [
                 {
                   text: "Cancel",
                   click: cancel,
                 },
                 {
                   text: "Edit",
                   click: function() {
                     confirm($dialog);
                   },
                 },
                ]
    });

    return $dialog;
  }

  return {
    create: create
  };
}($);

var QuickAddDialog = function($) {
  function confirm($dialog) {
    var $form = $('#curs-quick-add-dialog form');
    if ($form.validate().form()) {
      $('#loading').unbind('ajaxStop.canto');
      $form.ajaxSubmit({
        dataType: 'json',
        success: function(data) {
          $dialog.dialog("destroy");
          var $dialog_div = $('#curs-quick-add-dialog');
          $dialog_div.remove();
          window.location.reload(false);
        }
      });
    }
  }

  function cancel() {
    $(this).dialog("destroy");
    var $dialog_div = $('#curs-quick-add-dialog');
    $dialog_div.remove();
  }

  function create(title, search_namespace, form_url) {
    var $dialog_div = $('#curs-quick-add-dialog');
    if ($dialog_div.length) {
      $dialog_div.remove()
    }

    var evidence_select_html = '<select id="ferret-quick-add-evidence" name="ferret-quick-add-evidence"><option selected="selected" value="">Choose an evidence type ...</option>'
    $.map(evidence_by_annotation_type[search_namespace],
          function(item) {
            evidence_select_html += '<option value="' + item + '">' + item + '</option>';
          });
    evidence_select_html += '</select>';

    var with_gene_html =
      '<select id="ferret-quick-add-with-gene" name="ferret-quick-add-with-gene">' +
      '<option selected="selected" value="">With gene ...</option>';
    $.map(genes_in_session,
          function(gene) {
            with_gene_html += '<option value="' + gene.id + '">' + gene.display_name + '</option>';
          });
    with_gene_html += '</select>';

    var dialog_html =
      '<div id="curs-quick-add-dialog" style="display: none">' +
      '<form action="' + form_url + '" method="post">' +
      '<input type="hidden" id="ferret-quick-add-term-id" name="ferret-quick-add-term-id"/>' +
      '<input id="ferret-quick-add-term-input" name="ferret-quick-add-term-entry" type="text"' +
      '       size="50" disabled="true" ' +
      '       placeholder="start typing and suggestions will be made ..." />' +
      '<br/>' +
      evidence_select_html +
      '<br/>' +
      '<div id="ferret-quick-add-with-gene-wrapper" style="display:none">' +
      with_gene_html +
      '</div>' +
      '<input id="ferret-quick-extension" name="ferret-quick-add-extension" type="text"' +
      '       size="50" ' +
      '       placeholder="Optional annotation extension ..." />' +
      '</form></div>';

    $dialog_div = $(dialog_html);

    var select_callback = function(event, ui) {
      $('#ferret-quick-add-term-id').val(ui.item.id);
    };

    var $form = $dialog_div.find('form');
    $form.validate({
      rules: {
        'ferret-quick-add-term-entry': {
          required: true,
        },
        'ferret-quick-add-evidence': {
          required: true,
        },
        'ferret-quick-add-with-gene': {
          required: function() {
           return $('#ferret-quick-add-with-gene').is(':visible');
          }
        }
      }
    });

    var $dialog = $dialog_div.dialog({
      modal: true,
      autoOpen: true,
      height: 'auto',
      width: 600,
      title: title,
      open: function() {
        var ferret_input = $('#ferret-quick-add-term-input');
        ferret_input.autocomplete({
          minLength: 2,
          source: make_ontology_complete_url(search_namespace),
          select: select_callback,
          cacheLength: 100,
        });
        ferret_input.attr('disabled', false);
      },
      buttons : [
                 {
                   text: "Cancel",
                   click: cancel,
                 },
                 {
                   text: "Add",
                   click: function() {
                     confirm($dialog);
                   },
                 },
               ],
    });

    var $with_gene_wrapper = $('#ferret-quick-add-with-gene-wrapper');

    $('#ferret-quick-add-evidence').on('change',
                                       function(event) {
                                         var evidence = $(this).val();
                                         if (evidence in with_gene_evidence_codes) {
                                           $with_gene_wrapper.show();
                                         } else {
                                           $with_gene_wrapper.hide();
                                         }
                                       })

    return $dialog;
  }

  return {
    create: create
  };
}($);

$(document).ready(function() {
  $('.curs-js-link').show();
});

function UploadGenesCtrl($scope) {
  $scope.data = {
    geneIdentifiers: '',
    noAnnotation: false,
    noAnnotationReason: '',
    otherText: '',
    geneList: '',
  };
  $scope.isValid = function() {
    return $scope.data.geneIdentifiers.length > 0 ||
      $scope.data.noAnnotation &&
      $scope.data.noAnnotationReason.length > 0 &&
      ($scope.data.noAnnotationReason !== "Other" ||
       $scope.data.otherText.length > 0);
  }
}

function SubmitToCuratorsCtrl($scope) {
  $scope.data = {
    reason: null,
    otherReason: '',
    hasAnnotation: false
  };
  $scope.noAnnotationReasons = [];

  $scope.init = function(reasons) {
    $scope.noAnnotationReasons = reasons;
  };

  $scope.validReason = function() {
    return $scope.data.reason != null && $scope.data.reason.length > 0 &&
      ($scope.data.reason !== 'Other' || $scope.data.otherReason.length > 0);
  };
}

