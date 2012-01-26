function last(a) { 
  return a[a.length-1]; 
}

function trim(a) {
  a=a.replace(/^\s+/,''); return a.replace(/\s+$/,'');
};

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

var ferret_choose = {
  // element 0 is the orginal text we searched for, last element is the current
  // selected term, the other elements are the history/trail
  term_history : [undefined],
  term_detail_cache : {},
  annotation_type: undefined,

  // the synonym we match when searching, if any
  matching_synonym : undefined,

  initialise : function(annotation_type) {
    ferret_choose.ontology_complete_url =
      application_root + 'ws/lookup/ontology/' + annotation_type;
    ferret_choose.annotation_type = annotation_type;
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
    $.ajax({
      url: ferret_choose.ontology_complete_url,
      data: { term: term_id, def: 1, children: 1 },
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
        $('#ferret-term-synonym-row').show();
        $('#ferret-term-synonym').html('<div class="term-synonym">' +
                                       ferret_choose.matching_synonym + '</div>');
      } else {
        $('#ferret-term-synonym-row').hide();
        $('#ferret-term-synonym').html('');
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

      var link_confs = ontology_external_links[ferret_choose.annotation_type];
      if (link_confs) {
        var html = '';
        $.each(link_confs, function(idx, link_conf) {
          var url = link_conf['url'];
          var re = /(@@term_ont_id@@)/;
          url = url.replace(re, term_id);
          var img_src =
            application_root + 'static/images/logos/' +
            link_conf['icon'];
          var title = link_conf['title'];
          html += '<div class="curs-external-link"><a href="' +
            url + '">';
          if (img_src) {
            html += '<img alt="' + title + '" src="' + img_src + '"/></a>'
          } else {
            html += title;
          }
          var link_img_src = application_root + 'static/images/ext_link.png';
          html += '<img src="' + link_img_src + '"/></div>';
        });
        $('#ferret-linkouts').html(html);
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
  }
};


var curs_home = {
  show_term_suggestion : function(term_ontid, name, definition) {
    var dialog_div = $('#curs-dialog');
    var html = '<div> Term name:' +
      '<span class="term-name">' + name + '</span></div>' +
      'Definition: <div class="term-definition">' + definition +
      '</div></div>';
    $('#curs-dialog').html(html);
    $('#curs-dialog').dialog({ modal: true,
                               title: 'Child term suggestion for ' +
                               term_ontid});
  }
};

$(document).ready(function() {
  var ferret_input = $("#ferret-term-input");

  if (ferret_input.size()) {
    ferret_input.autocomplete({
      minLength: 2,
      source: ferret_choose.ontology_complete_url,
      cacheLength: 100,
      mustMatch: false,
      selectFirst: true,
      select: function(event, ui) {
        ferret_choose.term_history =[trim(ferret_input.val())];
        ferret_choose.set_current_term(ui.item.id);
        ferret_choose.matching_synonym = ui.item.matching_synonym;
        return false;
      }
    })
    .data("autocomplete")._renderItem = function( ul, item ) {
      var search_string = $('#ferret-term-input').val();
      var search_bits = search_string.split(/\W+/);
      var match_name = item.matching_synonym;
      var synonym_extra = '';
      if (match_name) {
        synonym_extra = ' (synonym)';
      } else {
        match_name = item.name;
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
                 item.id + ")</span>" + synonym_extra + "</a>" )
        .appendTo( ul );
    };

    function do_autocomplete () {
      ferret_input.focus();
      ferret_input.autocomplete('search');
    }

    ferret_input.bind('paste', function() {
      setTimeout(do_autocomplete, 10);
    });

    $('#ferret-test-do-search').click(function () {
      ferret_choose.term_selected($('#ferret-term-input').val());
    });

    ferret_input.keypress(function(event) {
      if (event.which == 13) {
        // return should autocomplete not submit the form
        event.preventDefault();
        ferret_input.autocomplete('search');
      }
    });

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

    $('.pomcur-toggle-button').each(function (index, element) {
      var this_id = $(element).attr('id');
      var target = $('#' + this_id + '-target');
      $(element).click(
        function () {
          target.toggle()
        }
      );
      $(element).show();
    });

    $('.pomcur-more-button').each(function (index, element) {
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

  $('a.pomcur-select-all').click(function () {
    $(this).closest('div').find('input:checkbox').attr('checked', true);
  });

  $('a.pomcur-select-none').click(function () {
    $(this).closest('div').find('input:checkbox').removeAttr('checked');
  });

  $('#curs-finish-publication').click(function () {
    window.location.href = curs_root_uri + '/finish_form';
  });

  $('#curs-check-completed').click(function () {
    window.location.href = curs_root_uri + '/check_completed';
  });

  $('#curs-finish-gene').click(function () {
    window.location.href = curs_root_uri;
  });

  $('#curs-contact-link').click(function () {
    $('#curs-contact-dialog').dialog({ modal: true,
                                       width: '50em' });
  });

  $('#curs-pub-assign-popup-dialog').click(function () {
    $('#curs-pub-assign-dialog').dialog({ modal: true,
                                          width: '50em' });
  });

  $('#curs-pub-assign-cancel').click(function () {
    $('#curs-pub-assign-dialog').hide();
  });


  $('#pubmed-id-lookup-form').ajaxForm({
    dataType: 'json',
    beforeSubmit: function() {
      $('#pubmed-id-lookup-waiting .ajax-spinner').show();
    },
    success: function(data) {
      $('#pubmed-id-lookup-waiting .ajax-spinner').hide();
      if (data.pub) {
        $('#pub-details-uniquename').html(data.pub.uniquename);
        $('#pub-details-uniquename').data('pubmedid', data.pub.uniquename);
        $('#pub-details-title').html(data.pub.title);
        $('#pub-details-authors').html(data.pub.authors);
        $('#pub-details-abstract').html(data.pub.abstract);
        $('#pubmed-id-lookup').hide();
        $('#pubmed-id-lookup-message').hide();
        $('#pubmed-id-lookup-pub-results').show();
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
    var base = window.location.href.match(new RegExp('(http://[^/]+)/([^/]+)'));
    var bits = base.splice(1);
    if (bits[1] != 'tools') {
      bits.push('tools');
    }
    window.location.href = bits.join('/') + '/start/' + pubmedid;
  });

  $('.non-key-attribute').jTruncate({  
        length: 300,  
        minTrail: 50,  
        moreText: "[show all]",  
        lessText: "[hide]"
    });
});
