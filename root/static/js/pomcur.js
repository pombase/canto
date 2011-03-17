function last(a) { 
  return a[a.length-1]; 
}

function trim(a) {
  a=a.replace(/^\s+/,''); return a.replace(/\s+$/,'');
};

$(document).ready(function() {
  $(".sect .sect-title").each(function(i) {
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
  term_history : [undefined],
  term_detail_cache : {},

  initialise : function(current_component) {
    ferret_choose.ontology_complete_url =
      application_root + 'ws/lookup/go/' + current_component;
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
      var i = 0;
      for (; i < ferret_choose.term_history.length; i++) {
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

    var bbq_state = {
      "s" : ferret_choose.term_history[0],
      "c" : ferret_choose.term_history.slice(1).join(",")
    };

    $.bbq.pushState(bbq_state);
  },

  add_to_breadcrumbs : function(term) {
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
    var div = $('<div class="hash-term"><a title="' +
               term.name + '" href="#' + term.id + '">' +
               term.name + "</a></div>");
    div.data('term', term);
    dest.append(div);
  },

  render_breadcrumbs : function(term_id) {
    $('#breadcrumbs-search').remove();
    if (ferret_choose.term_history.length > 1) {
      var html = '<li id="breadcrumbs-search">Search: "' + 
        ferret_choose.term_history[0] + '"</li>';
      $('#breadcrumbs ul').append(html);
      for (var i = 1; i < ferret_choose.term_history.length - 1; i++) {
        var term_id = ferret_choose.term_history[i];
        var term = ferret_choose.get_term_by_id(term_id);
        ferret_choose.add_to_breadcrumbs(term);
      }
    };
  },

  move_to_hash_term : function(link) {
    var href = link.attr('href');
    var term_id = href.substring(href.indexOf('#') + 1);
    ferret_choose.set_current_term(term_id);
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

      ferret_choose.debug("render(): " + term_id + " " + term.name);

      var children = term.children;
      var children_html = '';

      $.each(children, function(idx, child) {
        var img_html =
          '<img src="' + application_root + '/static/images/right_arrow.png"/>';
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
    var html = '<div> Term name:' +
      '<span class="term-name">' + name + '</span></div>' +
      'Definition: <div class="term-definition">' + definition +
      '</div></div>';
    $('#term-suggestion').html(html);
    $('#term-suggestion').dialog({ modal: true,
                                   title: 'Child term suggestion for ' +
                                     term_ontid});
  }
};

$(document).ready(function() {
  var ferret_input = $("#ferret-term-input");

  if (ferret_input.size()) {
    ferret_input.keyup(function() {
      ferret_choose.term_history = [trim($('#ferret-term-input').val())];
    });
    ferret_input.autocomplete({
      minLength: 2,
      source: ferret_choose.ontology_complete_url,
      select: function(event, ui) {
        ferret_choose.set_current_term(ui.item.id);
        return false;
      }
    })
    .data("autocomplete")._renderItem = function( ul, item ) {
      var search_string = $('#ferret-term-input').val();
      var search_bits = search_string.split(/\s+/);
      var match_name = item.name;
      for (var i = 0; i < search_bits.length; i++) {
        var bit = search_bits[i];
        if (bit.length > 0) {
          var re = new RegExp('(' + bit + ')', "gi");
          match_name = match_name.replace(re,'<b>$1</b>');
        }
      }
      return $( "<li></li>" )
        .data( "item.autocomplete", item )
        .append( "<a>" + match_name + " <span class='term-id'>(" +
                 item.id + ")</span></a>" )
        .appendTo( ul );
    };

    $('#ferret-test-do-search').click(function () {
      ferret_choose.term_selected($('#ferret-term-input').val());
    });

    ferret_input.keypress(function(event) {
      if (event.which == 13) {
        // disable return
        event.preventDefault();
      }
    });

    $("body").delegate("#ferret-term-children-list a", "click",
                       ferret_choose.child_click_handler);
    $("body").delegate("#breadcrumbs .hash-term a", "click",
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
        window.location.href = curs_root_path;
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
      window.location.href = curs_root_path;
    });

  }
});
