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
  })
});

$(function() {
  var ontology_complete_url = application_root + '/ws/lookup/go/component';

  var use_term_data = function(data) {
    $('#ontology-term-definition').text(data[0].definition);

    var children = data[0].children;
    var children_html = '';

    $.each(children, function(idx, child) {
      children_html += '<li>' + child.name + ' (' + child.id + ')</li>';
    });

    $('#ontology-term-children').html($('<ul/>').append($(children_html)));
  }

  var term_selected = function() {
    var term_id = $('#ontology-term-id').val();
    if (term_id) {
      $.ajax({
        url: ontology_complete_url + '/term',
        data: { term: term_id, def: 1, children: 1 },
        dataType: 'json',
        success: use_term_data
      });
    }
  };

  var set_term = function(term) {
    $('#ontology-term-id').val(term.id);
    $('#ontology-term-entry').val(term.name);
  };

  $( "#ontology-term-entry" ).autocomplete({
    minLength: 2,
    source: ontology_complete_url + '/term',
    focus: function(event, ui) {
      $('#ontology-term-entry').val(ui.item.name);
      return false;
    },
    select: function(event, ui) {
      set_term(ui.item);
      return false;
    },
    close: term_selected
  })
  .data( "autocomplete" )._renderItem = function( ul, item ) {
    return $( "<li></li>" )
      .data( "item.autocomplete", item )
      .append( "<a>" + item.id + "<br>" + item.name + "</a>" )
      .appendTo( ul );
  };
});

